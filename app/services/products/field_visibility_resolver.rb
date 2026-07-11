# frozen_string_literal: true

module Products
  class FieldVisibilityResolver
    FieldState = Data.define(:visible, :required)

    FIELD_KEYS = %i[
      item_kind primary_identifier title list_price digital creators store_category subdepartment
      preferred_vendor default_display_location
      variation_type variant_label_1 variant_label_2 thumbnail format publisher publication_date
      publication_status large_print edition_statement bisac_picker genre_scheme_picker
      free_text_genres subjects series_name page_count running_time year target_audience
      access_restrictions language description physical_dimensions weight internal_notes active
      periodical_metadata calendar_metadata
    ].freeze

    SHORT_FORM_VISIBLE = %i[
      item_kind title subdepartment list_price description internal_notes active
    ].freeze

    SHORT_FORM_REQUIRED = %i[item_kind title subdepartment].freeze

    KIND_DEFAULTS = {
      "book" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        digital: :visible, creators: :visible, store_category: :visible, subdepartment: :required,
        variation_type: :visible, thumbnail: :visible, format: :visible, publisher: :visible,
        publication_date: :visible, publication_status: :visible, edition_statement: :visible,
        bisac_picker: :visible, subjects: :conditional, series_name: :visible,
        page_count: :conditional, running_time: :conditional, large_print: :conditional,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, physical_dimensions: :conditional, weight: :conditional,
        internal_notes: :visible, active: :visible
      },
      "recorded_music" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        digital: :visible, creators: :visible, store_category: :visible, subdepartment: :required,
        variation_type: :visible, thumbnail: :visible, format: :visible, publisher: :conditional,
        publication_date: :conditional, publication_status: :conditional, edition_statement: :conditional,
        genre_scheme_picker: :visible, running_time: :conditional,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, physical_dimensions: :conditional, weight: :conditional,
        internal_notes: :visible, active: :visible
      },
      "videorecording" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        digital: :visible, creators: :visible, store_category: :visible, subdepartment: :required,
        variation_type: :visible, thumbnail: :visible, format: :visible, publisher: :conditional,
        publication_date: :conditional, publication_status: :conditional, edition_statement: :conditional,
        genre_scheme_picker: :visible, subjects: :conditional, series_name: :conditional,
        running_time: :visible, target_audience: :visible, access_restrictions: :visible,
        language: :visible, description: :visible, physical_dimensions: :conditional,
        weight: :conditional, internal_notes: :visible, active: :visible
      },
      "game" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        digital: :visible, creators: :visible, store_category: :visible, subdepartment: :required,
        variation_type: :visible, thumbnail: :visible, format: :visible, publisher: :conditional,
        publication_date: :conditional, publication_status: :conditional, edition_statement: :conditional,
        genre_scheme_picker: :visible, series_name: :conditional,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, physical_dimensions: :conditional, weight: :conditional,
        internal_notes: :visible, active: :visible
      },
      "periodical" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        creators: :hidden, store_category: :visible, subdepartment: :required, variation_type: :visible,
        thumbnail: :visible, format: :visible, publication_date: :conditional,
        publication_status: :conditional, periodical_metadata: :visible,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, internal_notes: :visible, active: :visible
      },
      "calendar" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        store_category: :visible, subdepartment: :required, variation_type: :visible, thumbnail: :visible,
        format: :visible, publication_date: :conditional, publication_status: :conditional,
        genre_scheme_picker: :visible, year: :required, calendar_metadata: :visible,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, physical_dimensions: :conditional, weight: :conditional,
        internal_notes: :visible, active: :visible
      },
      "sideline" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        creators: :hidden, store_category: :visible, subdepartment: :required, variation_type: :visible,
        thumbnail: :visible, format: :visible, publication_date: :conditional,
        publication_status: :conditional, genre_scheme_picker: :visible, year: :conditional,
        page_count: :conditional, subjects: :conditional,
        target_audience: :visible, access_restrictions: :visible, language: :visible,
        description: :visible, physical_dimensions: :conditional, weight: :conditional,
        internal_notes: :visible, active: :visible
      },
      "other" => {
        item_kind: :required, primary_identifier: :visible, title: :required, list_price: :visible,
        store_category: :visible, subdepartment: :required, variation_type: :visible, thumbnail: :visible,
        format: :conditional, publication_date: :conditional, publication_status: :conditional,
        free_text_genres: :conditional, description: :visible, physical_dimensions: :conditional,
        weight: :conditional, internal_notes: :visible, active: :visible
      }
    }.freeze

    GENRE_SCHEME_BY_KIND = {
      "recorded_music" => "music_genres",
      "videorecording" => "video_genres",
      "game" => "video_game_genres",
      "sideline" => "sideline_genres",
      "calendar" => "sideline_genres"
    }.freeze

    AUDIOBOOK_FORMAT_KEYS = %w[audiobook_download audiobook_streaming audiobook_cd audiobook_digital].freeze
    EBOOK_FORMAT_KEYS = %w[ebook epub].freeze

    def self.resolve(**kwargs)
      new(**kwargs).resolve
    end

    def initialize(staff_item_kind:, digital: false, format: nil, variation_type: nil, product_type: nil)
      @staff_item_kind = staff_item_kind.to_s
      @digital = digital
      @format = format
      @variation_type = variation_type.to_s.presence
      @product_type = product_type
    end

    def resolve
      if short_form?
        return short_form_states
      end

      states = base_states
      apply_selling_defaults_visibility!(states)
      apply_digital_overrides!(states)
      apply_variation_overrides!(states)
      apply_format_overrides!(states)
      states
    end

    def controlled_scheme
      return nil if short_form?

      return Bisac::CategoryNodeImporter::SCHEME_KEY if @staff_item_kind == "book"

      GENRE_SCHEME_BY_KIND[@staff_item_kind]
    end

    def short_form?
      @staff_item_kind.in?(%w[service non_inventory])
    end

    private

    def short_form_states
      FIELD_KEYS.index_with do |key|
        visible = SHORT_FORM_VISIBLE.include?(key)
        required = SHORT_FORM_REQUIRED.include?(key)
        FieldState.new(visible: visible, required: required)
      end
    end

    def base_states
      defaults = KIND_DEFAULTS.fetch(@staff_item_kind, KIND_DEFAULTS.fetch("other"))
      FIELD_KEYS.index_with do |key|
        state = defaults[key] || :hidden
        FieldState.new(visible: state.in?(%i[visible required conditional]), required: state == :required)
      end
    end

    def apply_selling_defaults_visibility!(states)
      states[:preferred_vendor] = FieldState.new(visible: true, required: false)
      states[:default_display_location] = FieldState.new(visible: true, required: false)
    end

    def apply_digital_overrides!(states)
      return unless @digital

      %i[physical_dimensions weight large_print page_count].each do |key|
        states[key] = FieldState.new(visible: false, required: false)
      end
    end

    def apply_variation_overrides!(states)
      case @variation_type
      when "variable"
        states[:variant_label_1] = FieldState.new(visible: true, required: false)
      when "matrix"
        states[:variant_label_1] = FieldState.new(visible: true, required: false)
        states[:variant_label_2] = FieldState.new(visible: true, required: false)
      else
        states[:variant_label_1] = FieldState.new(visible: false, required: false)
        states[:variant_label_2] = FieldState.new(visible: false, required: false)
      end
    end

    def apply_format_overrides!(states)
      return if @format.blank?

      format_key = @format.is_a?(Format) ? @format.format_key : @format.to_s

      if AUDIOBOOK_FORMAT_KEYS.include?(format_key)
        states[:running_time] = FieldState.new(visible: true, required: false)
      end

      if format_key == "audiobook_cd"
        states[:physical_dimensions] = FieldState.new(visible: true, required: false)
        states[:weight] = FieldState.new(visible: true, required: false)
      end

      if @staff_item_kind == "book" && !@digital && format_key.in?(%w[trade_cloth trade_paperback mass_market_paperback library_binding])
        states[:large_print] = FieldState.new(visible: true, required: false)
        states[:page_count] = FieldState.new(visible: true, required: false)
      end
    end
  end
end
