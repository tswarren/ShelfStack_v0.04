# frozen_string_literal: true

module Items
  class ItemPresenter
    include Rails.application.routes.url_helpers

    attr_reader :catalog_item, :product

    def self.from_catalog_item(catalog_item)
      return new(catalog_item: nil, product: nil) if catalog_item.blank?

      product = catalog_item.products.active_records.order(:id).first
      return from_product(product) if product.present?

      new(catalog_item: catalog_item, product: nil)
    end

    def self.from_product(product)
      new(product: product)
    end

    def self.from_product_variant(variant)
      from_product(variant.product)
    end

    def self.from_search_hit(hit)
      case hit[:record_type]
      when "catalog_item"
        from_catalog_item(hit[:record])
      when "product", "product_identifier"
        from_product(hit[:record])
      when "product_variant"
        from_product_variant(hit[:record])
      else
        raise ArgumentError, "Unknown search hit type: #{hit[:record_type]}"
      end
    end

    def initialize(catalog_item: nil, product: nil)
      @catalog_item = catalog_item || product&.catalog_item
      @product = product
    end

    def title
      if product.present?
        product.title.presence || product.name.presence || "Untitled Item"
      else
        catalog_item&.title || "Untitled Item"
      end
    end

    def primary_identifier
      product ? product.primary_identifier : nil
    end

    def primary_identifier_display
      primary_identifier&.normalized_identifier || "—"
    end

    def product_sku
      product&.sku
    end

    def variants
      return ProductVariant.none if product.blank?

      product.product_variants.active_records.includes(:condition, :sub_department).order(:sku)
    end

    def active_variant_count
      variants.size
    end

    def variant_summary_label
      active_variants = variants.to_a
      return "—" if active_variants.empty?

      active_variants.map { |variant| variant_label(variant) }.uniq.join(", ")
    end

    def catalog_linked?
      product&.catalog_linked? || catalog_item.present?
    end

    def sellable?
      product&.sellable?
    end

    def creator_line
      display_metadata&.creators.presence || "—"
    end

    def creator_names
      source = display_metadata&.creators
      return [] if source.blank?

      source.split(";").map(&:strip).reject(&:blank?)
    end

    def creator_entries
      source = display_metadata&.creators
      return [] if source.blank?

      MetadataParser.parse_creators(source)
    end

    def subtitle
      meta = display_metadata
      meta&.subtitle.presence || meta&.edition_statement.presence
    end

    def format_name
      display_metadata&.format&.name || "—"
    end

    def format_label
      format_record = display_metadata&.format
      return "—" unless format_record

      code = format_record.code.presence || format_record.short_name
      code.present? ? "#{format_record.name} (#{code})" : format_record.name
    end

    def released_label
      released_date_label.presence || publication_status_label || "—"
    end

    def released_date_label
      meta = display_metadata
      return nil unless meta

      if meta.publication_date.present?
        meta.publication_date.strftime("%B %-d, %Y")
      elsif meta.year.present?
        meta.year.to_s
      end
    end

    def publication_status_label
      status = display_metadata&.publication_status
      return nil if status.blank?

      humanize_status(status)
    end

    def primary_identifier_label
      return "—" unless primary_identifier

      type_label = primary_identifier.validation_family.upcase
      "#{primary_identifier.normalized_identifier} (#{type_label})"
    end

    def series_label
      meta = display_metadata
      name = meta&.series_name
      return "—" if name.blank?

      enumeration = meta&.series_enumeration
      label = name
      label += " (#{enumeration})" if enumeration.present?
      label
    end

    def pages_label
      count = display_metadata&.page_count
      count.present? ? count.to_s : nil
    end

    def dimensions_label
      meta = display_metadata
      return nil unless meta

      dims = [ meta.height, meta.width, meta.depth ].compact
      return nil if dims.empty? && meta.weight.blank?

      parts = []
      if dims.any?
        unit = meta.dimension_units.presence || "in"
        parts << dims.map { |value| value.to_i == value ? value.to_i : value }.join(" x ") + " #{unit}"
      end
      if meta.weight.present?
        weight_unit = meta.weight_units.presence || "lb"
        weight = meta.weight.to_i == meta.weight ? meta.weight.to_i : meta.weight
        parts << "(#{weight} #{weight_unit}.)"
      end
      parts.join(" ")
    end

    def running_time_label
      minutes = display_metadata&.duration_minutes
      return nil unless minutes.present?

      "#{minutes} minutes"
    end

    def pub_frequency_label
      frequency = display_metadata&.publication_frequency
      return nil if frequency.blank?

      humanize_status(frequency)
    end

    def catalog_facts
      meta = display_metadata
      [
        [ "Format", format_name ],
        [ "Released", released_date_label ],
        [ "Publisher", meta&.publisher ],
        [ "Primary Identifier", primary_identifier_label ],
        [ "Series", series_label ],
        [ "Pages", pages_label ],
        [ "Dimensions", dimensions_label ],
        [ "Running Time", running_time_label ],
        [ "Pub. Frequency", pub_frequency_label ]
      ].filter_map do |label, value|
        next if value.blank? || value == "—"

        [ label, value ]
      end
    end

    def subject_headings
      subject_groups.flat_map { |group| group[:headings] }.first(5)
    end

    def subject_groups
      meta = display_metadata
      return [] unless meta

      [
        { label: "Subjects", headings: cleaned_headings_from(bisac_subject_source) },
        { label: "Genres", headings: cleaned_headings_from({ data: meta.genre_data, raw: meta.genres }) },
        { label: "Themes", headings: cleaned_headings_from({ data: meta.theme_data, raw: meta.themes }) },
        { label: "Audiences", headings: cleaned_headings_from({ data: meta.target_audience_data, raw: meta.target_audiences }) },
        { label: "Access Restrictions", headings: cleaned_headings_from({ data: meta.access_restriction_data, raw: meta.access_restrictions }) }
      ].reject { |group| group[:headings].empty? }
    end

    def overview_eyebrow_label(variant: nil)
      store_category_label = display_metadata&.store_category&.breadcrumb_label
      return store_category_label if store_category_label.present?

      resolved_variant = variant_for_eyebrow(variant)
      return nil if resolved_variant.blank?

      SubdepartmentDisplayResolver.name_for(variant: resolved_variant, product: product)
    end

    def overview_header_badges
      meta = display_metadata
      badges = []
      badges << { key: :digital, label: "Digital" } if meta&.digital?
      badges << { key: :large_print, label: "Large Print" } if meta&.large_print?
      badges
    end

    def product_facts_for_overview
      meta = display_metadata
      facts = []

      if product&.list_price_cents.present?
        facts << [ "List Price", format_cents(product.list_price_cents) ]
      end

      identifier_label = primary_identifier_label
      facts << [ "Primary Identifier", identifier_label ] if identifier_label != "—"

      format_value = format_label
      if format_value != "—"
        facts << [ "Format", format_value ]
      end

      facts << [ "Publisher / Manufacturer", meta.publisher ] if meta&.publisher.present?

      if released_date_label.present?
        facts << [ "Publication Date", released_date_label ]
      elsif meta&.year.present?
        facts << [ "Publication Date", meta.year.to_s ]
      end

      details = details_label
      facts << [ "Details", details ] if details.present?

      facts
    end

    def details_label
      parts = []
      parts << description_summary_label if description_summary_label.present?
      parts << dimensions_label if dimensions_label.present?
      parts.join(" · ").presence
    end

    def description_summary_label
      meta = display_metadata
      parts = []
      parts << "#{pages_label} pp." if pages_label.present?
      parts << running_time_label if running_time_label.present?
      parts << pub_frequency_label if pub_frequency_label.present?
      if meta&.year.present? && released_date_label.blank?
        parts << meta.year.to_s
      end
      parts.join(" · ").presence
    end

    def catalog_item_type_label
      product_record = product || (catalog_item.is_a?(Product) ? catalog_item : nil)
      if product_record.present?
        staff_kind = Products::ItemKindNormalizer.infer_staff_item_kind(product_record)
        return Products::ItemKindNormalizer.staff_label(staff_kind)
      end

      type = display_metadata&.catalog_item_type
      return nil if type.blank?

      humanize_status(Products::ItemKindNormalizer.normalize_legacy_catalog_item_type(type))
    end

    def description_text
      display_metadata&.description.presence
    end

    def description_long?(length: 280)
      description_text.to_s.length > length
    end

    def overview_actions(helper: self)
      actions = []
      if path = edit_bibliographic_metadata_path(helper: helper)
        actions << {
          label: "Edit bibliographic details",
          url: path
        }
      end
      if product
        actions << {
          label: "Edit Product",
          url: helper.edit_items_product_path(product, item_return_params)
        }
      end
      actions
    end

    def variant_location_label(variant)
      variant.display_location&.name || variant.sub_department&.name || "—"
    end

    def classification_summary_for(variant)
      defaults = ClassificationDefaultsResolver.for(variant: variant)

      {
        sub_department: variant.sub_department&.name,
        store_category: display_metadata&.store_category&.breadcrumb_label,
        condition: variant.condition&.short_name || variant.condition&.name,
        display_location: variant.display_location&.name,
        defaults: defaults
      }
    end

    def classification_summary_label(variant)
      summary = classification_summary_for(variant)
      parts = [
        summary[:sub_department],
        summary[:store_category],
        summary[:condition]
      ].compact
      parts.presence&.join(" · ") || "—"
    end

    def topic_section_label(variant: nil)
      display_metadata&.store_category&.breadcrumb_label
    end

    def variant_for_eyebrow(variant)
      return variant if variant.present?

      variants.find { |entry| entry.categorizations.primary_records.any? } || variants.first
    end

    def display_location_path(variant: nil)
      location = primary_display_location(variant: variant)
      return [] unless location

      location.ancestor_chain
    end

    def primary_display_location(variant: nil)
      if variant&.display_location.present?
        return variant.display_location
      end

      return product.default_display_location if product&.default_display_location.present?

      variants.find { |entry| entry.display_location.present? }&.display_location
    end

    def edit_catalog_path(helper: self)
      edit_bibliographic_metadata_path(helper: helper)
    end

    def edit_bibliographic_metadata_path(helper: self)
      if catalog_item.present?
        helper.edit_items_catalog_item_path(catalog_item, item_return_params)
      elsif product&.metadata_fused?
        helper.edit_metadata_items_product_path(product, item_return_params)
      end
    end

    def cover_image_attached?
      product&.cover_image&.attached?
    end

    def price_range_label
      prices = variants.map(&:selling_price_cents).compact
      return "—" if prices.empty?

      min_price = prices.min
      max_price = prices.max
      if min_price == max_price
        format_cents(min_price)
      else
        "#{format_cents(min_price)} – #{format_cents(max_price)}"
      end
    end

    def basic_statuses
      ItemLifecycleStatus.basic(self)
    end

    def search_statuses
      basic_statuses - [ "invalid_identifier_warning" ]
    end

    def full_statuses
      ItemLifecycleStatus.full(self)
    end

    def primary_status
      basic_statuses.first
    end

    def show_path(helper: self, tab: nil, variant_id: nil, anchor: nil)
      params = route_params.dup
      params[:tab] = tab if tab.present? && tab != "overview"
      params[:variant_id] = variant_id if variant_id.present?
      path = helper.items_item_path(params)
      anchor.present? ? "#{path}##{anchor}" : path
    end

    def tab_path(tab, helper: self, variant_id: nil, anchor: nil)
      show_path(helper: helper, tab: tab, variant_id: variant_id, anchor: anchor)
    end

    def context_actions(helper: self)
      [
        create_product_action(helper: helper),
        create_first_sku_action(helper: helper),
        sell_new_action(helper: helper),
        edit_catalog_action(helper: helper),
        *used_condition_actions(helper: helper)
      ].compact
    end

    def route_params
      if product.present?
        { product_id: product.id }
      elsif catalog_item.present?
        { catalog_item_id: catalog_item.id }
      else
        {}
      end
    end

    def ==(other)
      other.is_a?(self.class) &&
        catalog_item&.id == other.catalog_item&.id &&
        product&.id == other.product&.id
    end

    def display_metadata
      product.presence || catalog_item
    end

    private

    def catalog_only_presenter?
      product.blank? && catalog_item.present?
    end

    def variant_label(variant)
      variant.list_label
    end

    def edit_catalog_action(helper: self)
      path = edit_bibliographic_metadata_path(helper: helper)
      return unless path

      { label: "Edit bibliographic details", url: path }
    end

    def sell_new_action(helper: self)
      return unless product
      return unless product.variation_type.in?(%w[standard conditional])

      condition = new_condition_record
      return unless condition
      return if variants.any? { |variant| variant.condition_id == condition.id }

      {
        label: "Sell New",
        url: helper.new_items_product_variant_path({ product_id: product.id, condition_id: condition.id }.merge(item_return_params))
      }
    end

    def create_product_action(helper: self)
      return unless catalog_item && product.blank?

      {
        label: "Create Store Product",
        url: helper.new_items_product_path({ catalog_item_id: catalog_item.id }.merge(item_return_params))
      }
    end

    def create_first_sku_action(helper: self)
      return unless product && variants.none?

      {
        label: "Create First Sellable SKU",
        url: helper.new_items_product_variant_path({ product_id: product.id }.merge(item_return_params))
      }
    end

    def used_condition_actions(helper: self)
      return [] unless product && product.variation_type.in?(%w[standard conditional])

      ProductCondition.active_records.where(new_condition: false).order(:sort_order).limit(3).map do |condition|
        {
          label: "Add #{condition.short_name} Copy",
          url: helper.new_items_product_variant_path({ product_id: product.id, condition_id: condition.id }.merge(item_return_params))
        }
      end
    end

    def item_return_params
      { return_to: "item" }
    end

    def new_condition_record
      @new_condition_record ||= ProductCondition.active_records.find_by(new_condition: true)
    end

    def subject_heading_sources
      meta = display_metadata
      return [] unless meta

      [
        bisac_subject_source,
        { data: meta.genre_data, raw: meta.genres },
        { data: meta.theme_data, raw: meta.themes }
      ]
    end

    def bisac_subject_source
      if product.present?
        if product.respond_to?(:bisac_categorizations)
          linked_headings = product.bisac_categorizations
            .order(primary: :desc, id: :asc)
            .map { |categorization| { "heading" => categorization.category_node.name } }
          return { data: linked_headings, raw: nil } if linked_headings.any?

          return { data: product.bisac_subject_data, raw: product.bisac_subjects } if product.bisac_subjects.present? || product.bisac_subject_data.present?
        end

        return { data: [], raw: nil }
      end

      return { data: [], raw: nil } unless catalog_item

      linked_headings = catalog_item.bisac_categorizations
        .order(primary: :desc, id: :asc)
        .map { |categorization| { "heading" => categorization.category_node.name } }
      return { data: linked_headings, raw: nil } if linked_headings.any?

      { data: catalog_item.bisac_subject_data, raw: catalog_item.bisac_subjects }
    end

    def headings_from_subject_source(source)
      parsed = Array(source[:data]).map { |entry| entry["heading"] }.reject(&:blank?)
      return parsed if parsed.any?
      return [] if source[:raw].blank?

      MetadataParser.parse_subjects(source[:raw]).map { |entry| entry["heading"] }
    end

    def clean_subject_heading(heading)
      heading.to_s.gsub(/\s*\[[^\]]*\]/, "").strip.presence
    end

    def cleaned_headings_from(source)
      headings_from_subject_source(source).filter_map { |heading| clean_subject_heading(heading) }.uniq
    end

    def humanize_status(value)
      value.to_s.tr("_", " ").titleize
    end

    def format_cents(cents)
      format("$%.2f", cents / 100.0)
    end
  end
end
