# frozen_string_literal: true

module Products
  # Shared visibility-field → param/attribute mapping for form shells, sanitizer, and preview.
  module FieldKeyRegistry
    PARAM_MAP = {
      title: :title,
      list_price: :list_price_cents,
      digital: :digital,
      creators: :creators,
      store_category: :store_category_id,
      subdepartment: :default_sub_department_id,
      preferred_vendor: :preferred_vendor_id,
      default_display_location: :default_display_location_id,
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

    PICKER_PARAM_KEYS = %i[
      primary_bisac_category_node_id
      bisac_category_node_ids
      bisac_subjects
      primary_genre_category_node_id
      genre_category_node_ids
    ].freeze

    module_function

    def visibility_keys
      FieldVisibilityResolver::FIELD_KEYS
    end

    def mapped_keys
      PARAM_MAP.keys
    end

    def param_keys_for(field_key)
      Array(PARAM_MAP[field_key.to_sym])
    end

    def consistent?
      unmapped = mapped_keys - visibility_keys
      unmapped.empty?
    end

    def drift_keys
      mapped_keys - visibility_keys
    end
  end
end
