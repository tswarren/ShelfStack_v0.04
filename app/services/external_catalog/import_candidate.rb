# frozen_string_literal: true

module ExternalCatalog
  class ImportCandidate
    class ImportError < StandardError; end

    Result = Struct.new(:import, :product, :catalog_item, :status, :message, :format, keyword_init: true)

    def self.finalize_create!(lookup_result:, product: nil, catalog_item: nil, actor:)
      resolved_product = product || catalog_item&.products&.active_records&.order(:id)&.first
      raise ImportError, "Product is required to finalize import." if resolved_product.blank?

      new(
        lookup_result: lookup_result,
        action_type: "create_catalog_item",
        actor: actor,
        format_id: nil,
        product_id: resolved_product.id
      ).finalize_create!(resolved_product)
    end

    def self.call(lookup_result:, action_type:, actor:, format_id: nil, catalog_item_id: nil, product_id: nil)
      resolved_product_id = resolve_boundary_product_id(product_id:, catalog_item_id:)
      new(
        lookup_result:,
        action_type:,
        actor:,
        format_id:,
        product_id: resolved_product_id
      ).call
    end

    def self.resolve_boundary_product_id(product_id:, catalog_item_id:)
      return product_id if product_id.present?
      return if catalog_item_id.blank?

      Product.find_by(id: catalog_item_id)&.id ||
        CatalogItem.find_by(id: catalog_item_id)&.products&.active_records&.order(:id)&.first&.id
    end

    def initialize(lookup_result:, action_type:, actor:, format_id:, product_id:)
      @lookup_result = lookup_result
      @action_type = action_type.to_s
      @actor = actor
      @format_id = format_id
      @product_id = product_id
      @source = @lookup_result.external_lookup_request.external_data_source
    end

    def call
      validate_action_type!

      preview = ImportPreview.call(lookup_result: @lookup_result)
      if preview.apply_blocked && @action_type != "skip"
        raise ImportError, preview.apply_blocked_reason
      end

      format = resolve_format(preview)

      ExternalCatalogImport.transaction do
        case @action_type
        when "skip"
          import = record_import!(status: "skipped", product: nil)
          Result.new(import: import, product: nil, catalog_item: nil, status: :skipped, message: "Import skipped.")
        when "create_catalog_item"
          duplicate = DuplicateDetector.call(isbn13: @lookup_result.isbn13, isbn10: @lookup_result.isbn10)
          if duplicate.duplicate?
            raise ImportError, "An existing product matches this ISBN. Link or fill blank instead."
          end

          format = resolve_format(preview)
          raise ImportError, "Select a format before continuing." if format.blank?

          Result.new(
            status: :staged,
            product: nil,
            catalog_item: nil,
            format: format,
            message: "Review item details and save to create the product record."
          )
        when "link_existing_catalog_item", "fill_blank_existing_catalog_item"
          product = find_target_product!(duplicate: preview.duplicate)
          apply_to_existing!(product:, format:, fill_blank_only: @action_type == "fill_blank_existing_catalog_item")
          import = record_import!(status: "applied", product: product)
          record_success_audit!(import, product)
          Result.new(
            import: import,
            product: product,
            catalog_item: product.catalog_item,
            status: :applied,
            message: "Product updated."
          )
        else
          raise ImportError, "Unsupported import action."
        end
      end
    rescue ImportError, ActiveRecord::RecordInvalid, AddItem::TransitionalSkuAssigner::ConflictError => e
      import = record_import!(status: "failed", product: nil, error_message: e.message)
      AuditEvents.record!(
        actor: @actor,
        event_name: "external_lookup.import_failed",
        auditable: import,
        details: { "action_type" => @action_type, "error" => e.message }
      )
      Result.new(import: import, product: nil, catalog_item: nil, status: :failed, message: e.message)
    end

    def finalize_create!(product)
      existing = ExternalCatalogImport.applied_imports.find_by(
        external_lookup_result: @lookup_result,
        product_id: product.id,
        action_type: @action_type
      )
      raise ActiveRecord::RecordNotUnique, "Import already finalized" if existing.present?

      import = record_import!(status: "applied", product: product)
      record_success_audit!(import, product)
      Result.new(
        import: import,
        product: product,
        catalog_item: product.catalog_item,
        status: :applied,
        message: "Product created."
      )
    end

    private

    def validate_action_type!
      return if ExternalCatalogImport::ACTION_TYPES.include?(@action_type)

      raise ImportError, "Invalid import action."
    end

    def resolve_format(preview)
      return preview.resolved_format if preview.resolved_format.present?
      return Format.active_records.find(@format_id) if @format_id.present?

      nil
    end

    def find_target_product!(duplicate:)
      product = if @product_id.present?
                  Product.find_by(id: @product_id)
      else
                  duplicate.product
      end
      raise ImportError, "Existing product is required for this action." if product.blank?

      product
    end

    def apply_to_existing!(product:, format:, fill_blank_only:)
      attrs = MetadataMapper.product_attributes(candidate: @lookup_result)
      attrs[:format] = format if format.present? && product.format_id.blank?

      attrs.each do |key, value|
        next if value.blank?

        if fill_blank_only
          product[key] = value if product[key].blank?
        else
          product[key] = value
        end
      end

      product.save!
      ensure_transitional_sku!(product)
      AuditEvents.record!(
        actor: @actor,
        event_name: "product.updated",
        auditable: product,
        details: { "source" => "external_catalog_import", "action_type" => @action_type }
      )
    end

    def ensure_transitional_sku!(product)
      return if product.sku.present?
      return if @lookup_result.isbn13.blank? && @lookup_result.isbn10.blank?

      ProductBuilder.assign_transitional_sku!(product:, candidate: @lookup_result, actor: @actor)
      product.save!
    end

    def record_import!(status:, product:, error_message: nil)
      ExternalCatalogImport.create!(
        external_lookup_result: @lookup_result,
        external_data_source: @source,
        status: status,
        action_type: @action_type,
        imported_by_user: @actor,
        product: product,
        catalog_item: product&.catalog_item,
        error_message: error_message,
        field_mapping_snapshot: MetadataMapper.product_attributes(candidate: @lookup_result),
        raw_payload_json: @lookup_result.raw_payload_json,
        applied_at: Time.current
      )
    end

    def record_success_audit!(import, product)
      AuditEvents.record!(
        actor: @actor,
        event_name: "external_lookup.imported",
        auditable: import,
        details: {
          "action_type" => @action_type,
          "product_id" => product.id
        }
      )
    end
  end
end
