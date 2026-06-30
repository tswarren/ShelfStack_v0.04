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
        Product.where(catalog_item_id: legacy["catalog_item_id"]).find_each do |product|
          copy_legacy_row_to_product!(product, legacy)
        end
      end
    end

    def copy_legacy_row_to_product!(product, legacy)
      identifier_type = legacy["identifier_type"].to_s
      family = LEGACY_TYPE_TO_FAMILY[identifier_type]
      return if family.blank?

      normalized = legacy["normalized_identifier"].to_s
      return if normalized.blank?
      return if legacy_row_present?(product, legacy)

      primary = legacy["primary_identifier"] && legacy["active"]

      identifier = ProductIdentifierService.add_identifier_for_legacy_type!(
        product: product,
        identifier_type: identifier_type,
        value: legacy["identifier_value"],
        primary: primary,
        source: legacy["source"].presence || "catalog_backfill"
      )

      apply_legacy_row_state!(legacy, identifier)
      @copied += 1
    rescue ProductIdentifierService::IdentifierError
      record_conflict!(
        product: product,
        validation_family: LEGACY_TYPE_TO_FAMILY[legacy["identifier_type"].to_s],
        normalized_identifier: legacy["normalized_identifier"],
        freeform_scope: freeform_scope_for(legacy["identifier_type"], legacy["normalized_identifier"])
      )
    end

    def apply_legacy_row_state!(legacy, created_identifier)
      target = created_identifier.reload

      target.update!(
        valid_check_digit: legacy["valid_check_digit"],
        validation_message: legacy["validation_message"],
        active: legacy["active"],
        metadata: (target.metadata || {}).merge("legacy_catalog_item_identifier_id" => legacy["id"])
      )

      target.update!(primary_identifier: false, active: false) unless legacy["active"]
    end

    def legacy_row_present?(product, legacy)
      family = LEGACY_TYPE_TO_FAMILY[legacy["identifier_type"].to_s]
      normalized = legacy["normalized_identifier"].to_s
      scope = freeform_scope_for(legacy["identifier_type"], normalized)

      case family
      when "gtin", "house"
        product.product_identifiers.exists?(validation_family: %w[gtin house], normalized_identifier: normalized)
      when "isbn"
        product.product_identifiers.exists?(validation_family: "isbn", normalized_identifier: normalized)
      when "freeform"
        product.product_identifiers.exists?(
          validation_family: "freeform",
          freeform_scope: scope,
          normalized_identifier: normalized
        )
      else
        false
      end
    end

    def backfill_from_product_sku!
      Product.find_each do |product|
        next if product.product_identifiers.active_records.exists?

        sku = product.sku.to_s.strip
        next if sku.blank?

        ProductIdentifierService.sync_from_product_sku!(product: product, source: "product_sku_backfill")
        @backfilled_from_sku += 1
      rescue ProductIdentifierService::IdentifierError
        family, scope = ProductIdentifierService.send(:classify_product_sku, sku)
        normalized = ProductIdentifierService.send(:normalize_sku_for_family, sku, family, scope)
        record_conflict!(product:, validation_family: family, normalized_identifier: normalized, freeform_scope: scope)
      end
    end

    def sync_primary_sku_caches!
      Product.find_each do |product|
        ProductIdentifierService.sync_product_sku_cache!(product)
      end
    end

    def record_conflict!(product:, validation_family:, normalized_identifier:, freeform_scope: nil)
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
  end
end
