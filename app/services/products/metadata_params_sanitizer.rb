# frozen_string_literal: true

module Products
  class MetadataParamsSanitizer
    FIELD_PARAM_MAP = {
      title: :title,
      list_price: :list_price_cents,
      digital: :digital,
      creators: :creators,
      store_category: :store_category_id,
      subdepartment: :default_sub_department_id,
      variation_type: :variation_type,
      variant_label_1: :variant1_label,
      variant_label_2: :variant2_label,
      format: :format_id,
      publisher: :publisher,
      publication_date: :publication_date,
      publication_status: :publication_status,
      large_print: :large_print,
      edition_statement: :edition_statement,
      description: :description,
      physical_dimensions: %i[height width depth dimension_units],
      weight: %i[weight weight_units],
      internal_notes: :internal_notes,
      active: :active,
      year: :year,
      page_count: :page_count,
      running_time: :duration_minutes,
      target_audience: :target_audiences,
      access_restrictions: :access_restrictions,
      language: :language_code,
      subjects: :themes,
      free_text_genres: :genres,
      series_name: %i[series_name series_enumeration],
      periodical_metadata: :publication_frequency,
      item_kind: :catalog_item_type
    }.freeze

    PRODUCT_METADATA_KEYS = (
      FIELD_PARAM_MAP.values.flatten +
      %i[
        staff_item_kind catalog_item_type primary_bisac_category_node_id bisac_category_node_ids
        bisac_subjects primary_genre_category_node_id genre_category_node_ids issue_number volume_number
      ]
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
      FIELD_PARAM_MAP.each do |field_key, param_keys|
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
