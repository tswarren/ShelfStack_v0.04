# frozen_string_literal: true

module IngramCatalogImport
  class Runner
    def self.call(path:, actor:, options:)
      new(path: path, actor: actor, options: options).call
    end

    def initialize(path:, actor:, options:)
      @path = path
      @actor = actor
      @options = options
      @result = ImportResult.new
    end

    def call
      @options.validate!
      rows = SpreadsheetParser.call(path: @path)

      rows.each do |row|
        process_row(row)
      end

      AuditEvents.record!(
        actor: @actor,
        event_name: "ingram_import.completed",
        details: @result.summary.merge("source_file" => File.basename(@path))
      )

      @result
    end

    private

    def process_row(row)
      unless row.valid?
        add_outcome(row, status: :skipped, message: "Missing required Product Name, identifier, or US SRP")
        return
      end

      format = FormatMapper.resolve!(row.format)
      catalog_item, catalog_status = upsert_catalog_item!(row, format)
      product, product_status, product_message = upsert_product!(row, catalog_item)
      variant_status = upsert_variant!(row, product)

      message = [product_message, variant_status[:message]].compact.join("; ").presence
      status = determine_status(catalog_status, product_status, variant_status)
      add_outcome(
        row,
        status: status,
        catalog_item_id: catalog_item.id,
        product_id: product&.id,
        product_variant_id: variant_status[:variant]&.id,
        message: message
      )
    rescue FormatMapper::FormatError,
           ProductTypeMapper::ProductTypeError,
           CatalogIdentifierService::IdentifierError,
           ActiveRecord::RecordInvalid => e
      add_outcome(row, status: :error, message: e.message)
    end

    def determine_status(catalog_status, product_status, variant_status)
      return :skipped if product_status == :skipped

      case variant_status[:status]
      when :variant_matched then return :variant_matched
      when :variant_created then return :variant_created
      end

      case product_status
      when :product_updated then return :product_updated
      when :product_created then return :product_created
      end

      catalog_status == :catalog_updated ? :catalog_updated : :catalog_created
    end

    def upsert_catalog_item!(row, format)
      resolution = IdentifierResolver.resolve(product_code: row.product_code, ean: row.ean)

      if resolution.conflict?
        raise ActiveRecord::RecordInvalid.new(CatalogItem.new.tap { |r| r.errors.add(:base, resolution.message) })
      end

      attrs = RowMapper.catalog_attributes(row: row, format: format)

      if resolution.found?
        catalog_item = resolution.catalog_item
        catalog_item.assign_attributes(attrs)
        changed = catalog_item.changed?
        catalog_item.save!
        ensure_identifiers!(catalog_item, row)
        sync_catalog_bisac!(catalog_item)
        record_audit!("catalog_item.updated", catalog_item) if changed
        [catalog_item, :catalog_updated]
      else
        catalog_item = CatalogItem.new(attrs)
        CatalogItem.transaction do
          catalog_item.save!
          create_identifiers!(catalog_item, row)
        end
        sync_catalog_bisac!(catalog_item.reload)
        record_audit!("catalog_item.created", catalog_item)
        [catalog_item.reload, :catalog_created]
      end
    end

    def upsert_product!(row, catalog_item)
      resolution = ProductResolver.resolve(catalog_item: catalog_item)

      if resolution.ambiguous?
        return [nil, :skipped, resolution.message]
      end

      if resolution.found?
        product = resolution.product
        previous_price = product.list_price_cents
        product.update!(list_price_cents: row.us_srp_cents)
        record_audit!("product.updated", product) if previous_price != row.us_srp_cents
        [product, :product_updated, nil]
      else
        product = Product.create!(
          catalog_item: catalog_item,
          active: true,
          product_type: "physical",
          variation_type: "conditional",
          list_price_cents: row.us_srp_cents
        )
        record_audit!("product.created", product)
        [product, :product_created, nil]
      end
    end

    def upsert_variant!(row, product)
      return { status: :skipped, message: "Product could not be resolved" } if product.blank?

      existing = VariantMatcher.find_new_variant(product: product)
      if existing
        return { status: :variant_matched, variant: existing }
      end

      condition = ProductCondition.active_records.find_by!(condition_key: "new")
      variant = ProductVariant.create!(
        product: product,
        condition: condition,
        category: @options.default_category,
        display_location: @options.default_display_location,
        active: true,
        inventory_behavior: AddItem::InventoryBehaviorMapper.for_product_type("physical"),
        selling_price_cents: AddItem::DefaultSellingPrice.cents(product: product, condition: condition)
      )
      record_audit!("product_variant.created", variant, details: { "sku" => variant.sku, "source" => "ingram_import" })
      if @options.default_primary_category_node.present?
        VariantTopicCategorization.sync!(
          variant: variant,
          category_node_id: @options.default_primary_category_node.id,
          source: "import"
        )
      end
      { status: :variant_created, variant: variant }
    end

    def create_identifiers!(catalog_item, row)
      if row.product_code.present?
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn10",
          value: row.product_code,
          primary: true,
          actor: @actor,
          source: "ingram_import"
        )
      elsif row.ean.present?
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn13",
          value: row.ean,
          primary: true,
          actor: @actor,
          source: "ingram_import"
        )
      end
    end

    def ensure_identifiers!(catalog_item, row)
      if row.product_code.present?
        normalized = CatalogIdentifierService.normalize_preview("isbn10", row.product_code)
        unless catalog_item.catalog_item_identifiers.active_records.exists?(identifier_type: "isbn10", normalized_identifier: normalized)
          CatalogIdentifierService.add_identifier!(
            catalog_item: catalog_item,
            identifier_type: "isbn10",
            value: row.product_code,
            primary: false,
            actor: @actor,
            source: "ingram_import"
          )
        end
      end

      if row.ean.present?
        normalized = CatalogIdentifierService.normalize_preview("isbn13", row.ean)
        unless catalog_item.catalog_item_identifiers.active_records.exists?(normalized_identifier: normalized)
          CatalogIdentifierService.add_identifier!(
            catalog_item: catalog_item,
            identifier_type: "isbn13",
            value: row.ean,
            primary: catalog_item.primary_identifier.blank?,
            actor: @actor,
            source: "ingram_import"
          )
        end
      end
    end

    def add_outcome(row, status:, message: nil, catalog_item_id: nil, product_id: nil, product_variant_id: nil)
      @result.add_outcome(
        ImportResult::RowOutcome.new(
          row_number: row.row_number,
          identifier: row.identifier_label,
          title: row.product_name,
          status: status,
          message: message,
          catalog_item_id: catalog_item_id,
          product_id: product_id,
          product_variant_id: product_variant_id
        )
      )
    end

    def record_audit!(event_name, auditable, details: {})
      AuditEvents.record!(
        actor: @actor,
        event_name: event_name,
        auditable: auditable,
        details: AuditEvents.build_details(auditable: auditable, event_name: event_name, extra: details)
      )
    end

    def sync_catalog_bisac!(catalog_item)
      CatalogItemBisacSync.sync!(
        catalog_item: catalog_item,
        bisac_subjects: catalog_item.bisac_subjects,
        structured: false,
        source: "import"
      )
    end
  end
end
