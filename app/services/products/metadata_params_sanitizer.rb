# frozen_string_literal: true

module Products
  class MetadataParamsSanitizer
    FIELD_PARAM_MAP = FieldKeyRegistry::PARAM_MAP

    PRODUCT_METADATA_KEYS = (
      FieldKeyRegistry::PARAM_MAP.values.flatten +
      FieldKeyRegistry::PICKER_PARAM_KEYS +
      %i[staff_item_kind catalog_item_type issue_number volume_number]
    ).uniq.freeze

    def self.sanitize(params:, entry_context:, mode: :new, item_kind_changed: false)
      new(params: params, entry_context: entry_context, mode: mode, item_kind_changed: item_kind_changed).sanitize
    end

    def initialize(params:, entry_context:, mode: :new, item_kind_changed: false)
      @params = params.to_h.deep_symbolize_keys
      @entry_context = entry_context
      @mode = mode.to_sym
      @item_kind_changed = item_kind_changed
    end

    def sanitize
      permitted = @params.slice(*PRODUCT_METADATA_KEYS)
      permitted[:catalog_item_type] = @entry_context.catalog_item_type if @entry_context.staff_item_kind.present?

      filter_to_visible_keys!(permitted)
      permitted[:_classification_cleanup] = true if @mode == :edit && @item_kind_changed
      permitted
    end

    private

    def filter_to_visible_keys!(permitted)
      FieldKeyRegistry::PARAM_MAP.each do |field_key, param_keys|
        Array(param_keys).each do |param_key|
          permitted.delete(param_key) unless @entry_context.visible?(field_key)
        end
      end

      unless @entry_context.visible?(:bisac_picker)
        permitted.delete(:primary_bisac_category_node_id)
        permitted.delete(:bisac_category_node_ids)
        permitted.delete(:bisac_subjects)
      end

      unless @entry_context.visible?(:genre_scheme_picker)
        permitted.delete(:primary_genre_category_node_id)
        permitted.delete(:genre_category_node_ids)
      end
    end
  end
end
