# frozen_string_literal: true

module V0042
  class BackfillProductIdentifiers
    LEGACY_TYPE_TO_FAMILY = {
      "isbn13" => "gtin",
      "ean" => "gtin",
      "upc" => "gtin",
      "gtin" => "gtin",
      "isbn10" => "isbn",
      "publisher_number" => "freeform",
      "local" => "freeform"
    }.freeze

    Result = Struct.new(:copied, :skipped_conflicts, :backfilled_from_sku, :needs_review_product_ids, keyword_init: true)

    def self.run!(logger: $stdout)
      new(logger: logger).run!
    end

    def initialize(logger: $stdout)
      @logger = logger
      @copied = 0
      @skipped_conflicts = []
      @backfilled_from_sku = 0
      @needs_review_product_ids = Set.new
    end

    def run!
      copy_legacy_catalog_identifiers_if_present!
      backfill_from_product_sku!
      sync_primary_sku_caches!

      Result.new(
        copied: @copied,
        skipped_conflicts: @skipped_conflicts,
        backfilled_from_sku: @backfilled_from_sku,
        needs_review_product_ids: @needs_review_product_ids.to_a
      )
    end

    private

    attr_reader :logger

    def copy_legacy_catalog_identifiers_if_present!
      connection = ActiveRecord::Base.connection
      return unless connection.table_exists?(:catalog_item_identifiers)

      connection.select_all("SELECT * FROM catalog_item_identifiers ORDER BY id").each do |legacy|
        product = Product.find_by(catalog_item_id: legacy["catalog_item_id"])
        next if product.blank?

        family = LEGACY_TYPE_TO_FAMILY[legacy["identifier_type"]]
        next if family.blank?

        freeform_scope = freeform_scope_for(legacy["identifier_type"], legacy["normalized_identifier"])
        next if insert_identifier!(
          product: product,
          validation_family: family,
          identifier_value: legacy["identifier_value"],
          normalized_identifier: legacy["normalized_identifier"],
          freeform_scope: freeform_scope,
          primary_identifier: legacy["primary_identifier"],
          valid_check_digit: legacy["valid_check_digit"],
          validation_message: legacy["validation_message"],
          source: legacy["source"].presence || "catalog_backfill",
          active: legacy["active"],
          metadata: { "legacy_catalog_item_identifier_id" => legacy["id"] }
        )
      end
    end

    def backfill_from_product_sku!
      Product.find_each do |product|
        next if product.product_identifiers.active_records.exists?

        sku = product.sku.to_s.strip.upcase
        next if sku.blank?

        family, scope = classify_product_sku(sku)
        next if family.blank?

        if insert_identifier!(
          product: product,
          validation_family: family,
          identifier_value: sku,
          normalized_identifier: normalize_for_family(sku, family, scope),
          freeform_scope: scope,
          primary_identifier: true,
          valid_check_digit: nil,
          validation_message: nil,
          source: "product_sku_backfill",
          active: true,
          metadata: {}
        )
          @backfilled_from_sku += 1
        end
      end
    end

    def sync_primary_sku_caches!
      Product.find_each do |product|
        ProductIdentifierService.sync_product_sku_cache!(product)
      end
    end

    def insert_identifier!(product:, validation_family:, identifier_value:, normalized_identifier:,
                           freeform_scope:, primary_identifier:, valid_check_digit:, validation_message:,
                           source:, active:, metadata:)
      if conflict?(product:, validation_family:, normalized_identifier:, freeform_scope:)
        record_conflict!(product:, validation_family:, normalized_identifier:, freeform_scope:)
        return false
      end

      ProductIdentifier.create!(
        product: product,
        validation_family: validation_family,
        identifier_value: identifier_value,
        normalized_identifier: normalized_identifier,
        freeform_scope: freeform_scope,
        primary_identifier: primary_identifier && active,
        valid_check_digit: valid_check_digit,
        validation_message: validation_message,
        source: source,
        active: active,
        metadata: metadata
      )
      @copied += 1
      true
    end

    def conflict?(product:, validation_family:, normalized_identifier:, freeform_scope:)
      case validation_family
      when "gtin", "house"
        ProductIdentifier.active_records
          .where(validation_family: %w[gtin house], normalized_identifier: normalized_identifier)
          .where.not(product_id: product.id)
          .exists?
      when "isbn"
        ProductIdentifier.active_records
          .where(validation_family: "isbn", normalized_identifier: normalized_identifier)
          .where.not(product_id: product.id)
          .exists?
      when "freeform"
        ProductIdentifier.active_records
          .where(
            product_id: product.id,
            validation_family: "freeform",
            freeform_scope: freeform_scope,
            normalized_identifier: normalized_identifier
          )
          .exists?
      else
        false
      end
    end

    def record_conflict!(product:, validation_family:, normalized_identifier:, freeform_scope:)
      @skipped_conflicts << {
        product_id: product.id,
        validation_family: validation_family,
        normalized_identifier: normalized_identifier,
        freeform_scope: freeform_scope
      }
      product.update!(needs_review: true)
      @needs_review_product_ids << product.id
      logger.puts "CONFLICT product=#{product.id} family=#{validation_family} value=#{normalized_identifier}"
    end

    def freeform_scope_for(identifier_type, normalized)
      return "legacy_local" if identifier_type == "local" || normalized.start_with?(ProductIdentifierService::LEGACY_LOCAL_PREFIX)
      return "legacy_product_sku" if normalized.start_with?(ProductIdentifierService::LEGACY_PRODUCT_SKU_PREFIX)
      return "publisher_number" if identifier_type == "publisher_number"

      "import_reference"
    end

    def classify_product_sku(sku)
      digits = sku.gsub(/[^0-9X]/, "")
      if sku.start_with?(ProductIdentifierService::LEGACY_LOCAL_PREFIX)
        [ "freeform", "legacy_local" ]
      elsif sku.start_with?(ProductIdentifierService::LEGACY_PRODUCT_SKU_PREFIX)
        [ "freeform", "legacy_product_sku" ]
      elsif [ 8, 12, 13, 14 ].include?(digits.length) && digits.match?(/\A[0-9]+\z/)
        [ "gtin", nil ]
      elsif digits.length == 10 && digits.match?(/\A[0-9]{9}[0-9X]\z/)
        [ "isbn", nil ]
      else
        [ "freeform", "import_reference" ]
      end
    end

    def normalize_for_family(value, family, scope)
      case family
      when "gtin" then value.gsub(/[^0-9]/, "")
      when "isbn" then value.gsub(/[^0-9X]/, "").upcase
      when "freeform"
        scope == "publisher_number" ? value.gsub(/[^A-Za-z0-9]/, "").upcase : value.upcase
      else
        value
      end
    end
  end
end
