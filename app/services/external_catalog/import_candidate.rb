# frozen_string_literal: true

module ExternalCatalog
  class ImportCandidate
    class ImportError < StandardError; end

    Result = Struct.new(:import, :catalog_item, :status, :message, :format, keyword_init: true)

    def self.finalize_create!(lookup_result:, catalog_item:, actor:)
      new(
        lookup_result: lookup_result,
        action_type: "create_catalog_item",
        actor: actor,
        format_id: nil,
        catalog_item_id: nil
      ).finalize_create!(catalog_item)
    end

    def self.call(lookup_result:, action_type:, actor:, format_id: nil, catalog_item_id: nil)
      new(
        lookup_result:,
        action_type:,
        actor:,
        format_id:,
        catalog_item_id:
      ).call
    end

    def initialize(lookup_result:, action_type:, actor:, format_id:, catalog_item_id:)
      @lookup_result = lookup_result
      @action_type = action_type.to_s
      @actor = actor
      @format_id = format_id
      @catalog_item_id = catalog_item_id
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
          import = record_import!(status: "skipped", catalog_item: nil)
          Result.new(import: import, catalog_item: nil, status: :skipped, message: "Import skipped.")
        when "create_catalog_item"
          duplicate = DuplicateDetector.call(isbn13: @lookup_result.isbn13, isbn10: @lookup_result.isbn10)
          if duplicate.duplicate?
            raise ImportError, "An existing catalog item matches this ISBN. Link or fill blank instead."
          end

          format = resolve_format(preview)
          raise ImportError, "Select a format before continuing." if format.blank?

          Result.new(
            status: :staged,
            catalog_item: nil,
            format: format,
            message: "Review item details and save to create the catalog record."
          )
        when "link_existing_catalog_item", "fill_blank_existing_catalog_item"
          catalog_item = find_target_catalog_item!(duplicate: preview.duplicate)
          apply_to_existing!(catalog_item:, format:, fill_blank_only: @action_type == "fill_blank_existing_catalog_item")
          import = record_import!(status: "applied", catalog_item: catalog_item)
          record_success_audit!(import, catalog_item)
          Result.new(import: import, catalog_item: catalog_item, status: :applied, message: "Catalog item updated.")
        else
          raise ImportError, "Unsupported import action."
        end
      end
    rescue ImportError, ActiveRecord::RecordInvalid, CatalogIdentifierService::IdentifierError => e
      import = record_import!(status: "failed", catalog_item: nil, error_message: e.message)
      AuditEvents.record!(
        actor: @actor,
        event_name: "external_lookup.import_failed",
        auditable: import,
        details: { "action_type" => @action_type, "error" => e.message }
      )
      Result.new(import: import, catalog_item: nil, status: :failed, message: e.message)
    end

    def finalize_create!(catalog_item)
      import = record_import!(status: "applied", catalog_item: catalog_item)
      record_success_audit!(import, catalog_item)
      Result.new(
        import: import,
        catalog_item: catalog_item,
        status: :applied,
        message: "Catalog item created."
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

    def find_target_catalog_item!(duplicate:)
      catalog_item = if @catalog_item_id.present?
                       CatalogItem.find(@catalog_item_id)
                     else
                       duplicate.catalog_item
                     end
      raise ImportError, "Existing catalog item is required for this action." if catalog_item.blank?

      catalog_item
    end

    def apply_to_existing!(catalog_item:, format:, fill_blank_only:)
      attrs = MetadataMapper.catalog_attributes(candidate: @lookup_result)
      attrs[:format] = format if format.present? && catalog_item.format_id.blank?

      attrs.each do |key, value|
        next if value.blank?

        if fill_blank_only
          catalog_item[key] = value if catalog_item[key].blank?
        else
          catalog_item[key] = value
        end
      end

      catalog_item.save!
      ensure_identifiers!(catalog_item)
      AuditEvents.record!(
        actor: @actor,
        event_name: "catalog_item.updated",
        auditable: catalog_item,
        details: { "source" => "external_catalog_import", "action_type" => @action_type }
      )
    end

    def ensure_identifiers!(catalog_item)
      if @lookup_result.isbn13.present? && !identifier_exists?(catalog_item, "isbn13", @lookup_result.isbn13)
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn13",
          value: @lookup_result.isbn13,
          primary: catalog_item.primary_identifier.blank?,
          actor: @actor,
          source: "isbndb"
        )
      end

      if @lookup_result.isbn10.present? && !identifier_exists?(catalog_item, "isbn10", @lookup_result.isbn10)
        CatalogIdentifierService.add_identifier!(
          catalog_item: catalog_item,
          identifier_type: "isbn10",
          value: @lookup_result.isbn10,
          primary: false,
          actor: @actor,
          source: "isbndb"
        )
      end
    end

    def identifier_exists?(catalog_item, type, normalized)
      catalog_item.catalog_item_identifiers.active_records.exists?(
        identifier_type: type,
        normalized_identifier: normalized
      )
    end

    def record_import!(status:, catalog_item:, error_message: nil)
      ExternalCatalogImport.create!(
        external_lookup_result: @lookup_result,
        external_data_source: @source,
        status: status,
        action_type: @action_type,
        imported_by_user: @actor,
        catalog_item: catalog_item,
        error_message: error_message,
        field_mapping_snapshot: MetadataMapper.catalog_attributes(candidate: @lookup_result),
        raw_payload_json: @lookup_result.raw_payload_json,
        applied_at: Time.current
      )
    end

    def record_success_audit!(import, catalog_item)
      AuditEvents.record!(
        actor: @actor,
        event_name: "external_lookup.imported",
        auditable: import,
        details: {
          "action_type" => @action_type,
          "catalog_item_id" => catalog_item.id
        }
      )
    end
  end
end
