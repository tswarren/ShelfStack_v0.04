# frozen_string_literal: true

module ExternalCatalog
  class ImportPreview
    FieldDiff = Struct.new(:field, :label, :current_value, :candidate_value, :action, keyword_init: true)

    Preview = Struct.new(
      :lookup_result,
      :duplicate,
      :resolved_format,
      :format_required,
      :apply_blocked,
      :apply_blocked_reason,
      :field_diffs,
      :allowed_actions,
      keyword_init: true
    )

    def self.call(lookup_result:)
      new(lookup_result:).call
    end

    def initialize(lookup_result:)
      @lookup_result = lookup_result
    end

    def call
      duplicate = DuplicateDetector.call(isbn13: @lookup_result.isbn13, isbn10: @lookup_result.isbn10)
      catalog_item = duplicate.catalog_item || @lookup_result.local_catalog_item
      resolved_format = CatalogImport::BindingFormatMapper.resolve(@lookup_result.binding_snapshot)
      format_required = resolved_format.blank?

      field_diffs = build_field_diffs(catalog_item)
      allowed_actions = allowed_actions_for(duplicate:, catalog_item:)

      Preview.new(
        lookup_result: @lookup_result,
        duplicate: duplicate,
        resolved_format: resolved_format,
        format_required: format_required,
        apply_blocked: false,
        apply_blocked_reason: nil,
        field_diffs: field_diffs,
        allowed_actions: allowed_actions
      )
    end

    private

    def build_field_diffs(catalog_item)
      candidate = @lookup_result
      fields = {
        title: [ catalog_item&.title, candidate.title ],
        subtitle: [ nil, candidate.subtitle ],
        creators: [ catalog_item&.creators, MetadataMapper.catalog_attributes(candidate: candidate)[:creators] ],
        publisher: [ catalog_item&.publisher, publisher_name(candidate) ],
        page_count: [ catalog_item&.page_count, candidate.pages ],
        language_code: [ catalog_item&.language_code, candidate.language_snapshot ],
        description: [ catalog_item&.description, candidate.synopsis ]
      }

      fields.map do |field, (current, proposed)|
        action = if catalog_item.blank?
                   :set
        elsif current.blank? && proposed.present?
                   :fill_blank
        elsif current.present? && proposed.present? && current.to_s != proposed.to_s
                   :conflict
        else
                   :unchanged
        end

        FieldDiff.new(
          field: field,
          label: field.to_s.humanize,
          current_value: current,
          candidate_value: proposed,
          action: action
        )
      end
    end

    def publisher_name(candidate)
      snapshot = candidate.publisher_snapshot
      snapshot["name"].presence || snapshot[:name].presence
    end

    def allowed_actions_for(duplicate:, catalog_item:)
      if duplicate.duplicate?
        %w[link_existing_catalog_item fill_blank_existing_catalog_item skip]
      else
        %w[create_catalog_item skip]
      end
    end
  end
end
