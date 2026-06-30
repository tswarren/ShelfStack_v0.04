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
      product = duplicate.product || @lookup_result.local_product || @lookup_result.local_catalog_item&.products&.active_records&.order(:id)&.first
      resolved_format = CatalogImport::BindingFormatMapper.resolve(@lookup_result.binding_snapshot)
      format_required = resolved_format.blank?

      field_diffs = build_field_diffs(product)
      allowed_actions = allowed_actions_for(duplicate:, product:)

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

    def build_field_diffs(product)
      candidate = @lookup_result
      fields = {
        title: [ product&.title, candidate.title ],
        subtitle: [ product&.subtitle, candidate.subtitle ],
        creators: [ product&.creators, MetadataMapper.product_attributes(candidate: candidate)[:creators] ],
        publisher: [ product&.publisher, publisher_name(candidate) ],
        page_count: [ product&.page_count, candidate.pages ],
        language_code: [ product&.language_code, candidate.language_snapshot ],
        description: [ product&.description, candidate.synopsis ]
      }

      fields.map do |field, (current, proposed)|
        action = if product.blank?
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

    def allowed_actions_for(duplicate:, product:)
      if duplicate.duplicate?
        %w[link_existing_catalog_item fill_blank_existing_catalog_item skip]
      else
        %w[create_catalog_item skip]
      end
    end
  end
end
