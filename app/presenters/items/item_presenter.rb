# frozen_string_literal: true

module Items
  class ItemPresenter
    include Rails.application.routes.url_helpers

    attr_reader :catalog_item, :product

    def self.from_catalog_item(catalog_item)
      product = catalog_item.products.active_records.order(:id).first
      new(catalog_item: catalog_item, product: product)
    end

    def self.from_product(product)
      new(catalog_item: product.catalog_item, product: product)
    end

    def self.from_product_variant(variant)
      from_product(variant.product)
    end

    def self.from_search_hit(hit)
      case hit[:record_type]
      when "catalog_item"
        from_catalog_item(hit[:record])
      when "product"
        from_product(hit[:record])
      when "product_variant"
        from_product_variant(hit[:record])
      when "catalog_item_identifier"
        from_catalog_item(hit[:record].catalog_item)
      else
        raise ArgumentError, "Unknown search hit type: #{hit[:record_type]}"
      end
    end

    def initialize(catalog_item: nil, product: nil)
      @catalog_item = catalog_item
      @product = product || catalog_item&.products&.active_records&.order(:id)&.first
    end

    def title
      catalog_item&.title || product&.name || "Untitled Item"
    end

    def primary_identifier
      catalog_item&.primary_identifier
    end

    def primary_identifier_display
      primary_identifier&.normalized_identifier || "—"
    end

    def product_sku
      product&.sku
    end

    def variants
      return ProductVariant.none if product.blank?

      product.product_variants.active_records.includes(:condition, :category).order(:sku)
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
      catalog_item.present?
    end

    def sellable?
      product&.sellable?
    end

    def creator_line
      catalog_item&.creators.presence || "—"
    end

    def creator_names
      return [] if catalog_item&.creators.blank?

      catalog_item.creators.split(";").map(&:strip).reject(&:blank?)
    end

    def creator_entries
      return [] if catalog_item&.creators.blank?

      MetadataParser.parse_creators(catalog_item.creators)
    end

    def subtitle
      catalog_item&.edition_statement.presence
    end

    def format_name
      catalog_item&.format&.name || "—"
    end

    def format_label
      return "—" unless catalog_item&.format

      format = catalog_item.format
      code = format.code.presence || format.short_name
      code.present? ? "#{format.name} (#{code})" : format.name
    end

    def released_label
      released_date_label.presence || publication_status_label || "—"
    end

    def released_date_label
      return nil unless catalog_item

      if catalog_item.publication_date.present?
        catalog_item.publication_date.strftime("%B %-d, %Y")
      elsif catalog_item.year.present?
        catalog_item.year.to_s
      end
    end

    def publication_status_label
      return nil unless catalog_item&.publication_status.present?

      humanize_status(catalog_item.publication_status)
    end

    def primary_identifier_label
      return "—" unless primary_identifier

      type_label = primary_identifier.identifier_type.tr("_", "-").upcase
      "#{primary_identifier.normalized_identifier} (#{type_label})"
    end

    def series_label
      return "—" unless catalog_item&.series_name.present?

      label = catalog_item.series_name
      label += " (#{catalog_item.series_enumeration})" if catalog_item.series_enumeration.present?
      label
    end

    def pages_label
      catalog_item&.page_count.present? ? catalog_item.page_count.to_s : nil
    end

    def dimensions_label
      return nil unless catalog_item

      item = catalog_item
      dims = [item.height, item.width, item.depth].compact
      return nil if dims.empty? && item.weight.blank?

      parts = []
      if dims.any?
        unit = item.dimension_units.presence || "in"
        parts << dims.map { |value| value.to_i == value ? value.to_i : value }.join(" x ") + " #{unit}"
      end
      if item.weight.present?
        weight_unit = item.weight_units.presence || "lb"
        weight = item.weight.to_i == item.weight ? item.weight.to_i : item.weight
        parts << "(#{weight} #{weight_unit}.)"
      end
      parts.join(" ")
    end

    def running_time_label
      return nil unless catalog_item&.duration_minutes.present?

      "#{catalog_item.duration_minutes} minutes"
    end

    def pub_frequency_label
      return nil if catalog_item&.publication_frequency.blank?

      humanize_status(catalog_item.publication_frequency)
    end

    def catalog_facts
      [
        ["Format", format_name],
        ["Released", released_date_label],
        ["Publisher", catalog_item&.publisher],
        ["Primary Identifier", primary_identifier_label],
        ["Series", series_label],
        ["Pages", pages_label],
        ["Dimensions", dimensions_label],
        ["Running Time", running_time_label],
        ["Pub. Frequency", pub_frequency_label]
      ].filter_map do |label, value|
        next if value.blank? || value == "—"

        [label, value]
      end
    end

    def subject_headings
      return [] unless catalog_item

      headings = subject_heading_sources.flat_map { |source| headings_from_subject_source(source) }
      headings.map { |heading| clean_subject_heading(heading) }.reject(&:blank?).uniq.first(5)
    end

    def description_text
      catalog_item&.description.presence
    end

    def description_long?(length: 280)
      description_text.to_s.length > length
    end

    def overview_actions(helper: self)
      actions = []
      if catalog_item
        actions << {
          label: "Edit Catalog Item",
          url: helper.edit_items_catalog_item_path(catalog_item)
        }
      end
      if product
        actions << {
          label: "Edit Product",
          url: helper.edit_items_product_path(product)
        }
      end
      actions
    end

    def variant_location_label(variant)
      variant.display_location&.name || variant.category&.name || "—"
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
      return unless catalog_item

      helper.edit_items_catalog_item_path(catalog_item)
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
      basic_statuses - ["invalid_identifier_warning"]
    end

    def full_statuses
      ItemLifecycleStatus.full(self)
    end

    def primary_status
      basic_statuses.first
    end

    def show_path(helper: self, tab: nil)
      params = route_params.dup
      params[:tab] = tab if tab.present? && tab != "overview"
      helper.items_item_path(params)
    end

    def tab_path(tab, helper: self)
      show_path(helper: helper, tab: tab)
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
      if catalog_item
        { catalog_item_id: catalog_item.id }
      else
        { product_id: product.id }
      end
    end

    def ==(other)
      other.is_a?(self.class) &&
        catalog_item&.id == other.catalog_item&.id &&
        product&.id == other.product&.id
    end

    private

    def variant_label(variant)
      variant.condition&.short_name.presence || variant.short_name.presence || variant.name
    end

    def edit_catalog_action(helper: self)
      return unless catalog_item

      { label: "Edit Catalog", url: helper.edit_items_catalog_item_path(catalog_item) }
    end

    def sell_new_action(helper: self)
      return unless product
      return unless product.variation_type.in?(%w[standard conditional])

      condition = new_condition_record
      return unless condition
      return if variants.any? { |variant| variant.condition_id == condition.id }

      {
        label: "Sell New",
        url: helper.new_items_product_variant_path(product_id: product.id, condition_id: condition.id)
      }
    end

    def create_product_action(helper: self)
      return unless catalog_item && product.blank?

      {
        label: "Create Store Product",
        url: helper.new_items_product_path(catalog_item_id: catalog_item.id)
      }
    end

    def create_first_sku_action(helper: self)
      return unless product && variants.none?

      {
        label: "Create First Sellable SKU",
        url: helper.new_items_product_variant_path(product_id: product.id)
      }
    end

    def used_condition_actions(helper: self)
      return [] unless product && product.variation_type.in?(%w[standard conditional])

      ProductCondition.active_records.where(new_condition: false).order(:sort_order).limit(3).map do |condition|
        {
          label: "Add #{condition.short_name} Copy",
          url: helper.new_items_product_variant_path(product_id: product.id, condition_id: condition.id)
        }
      end
    end

    def new_condition_record
      @new_condition_record ||= ProductCondition.active_records.find_by(new_condition: true)
    end

    def subject_heading_sources
      [
        { data: catalog_item.bisac_subject_data, raw: catalog_item.bisac_subjects },
        { data: catalog_item.genre_data, raw: catalog_item.genres },
        { data: catalog_item.theme_data, raw: catalog_item.themes }
      ]
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

    def humanize_status(value)
      value.to_s.tr("_", " ").titleize
    end

    def format_cents(cents)
      format("$%.2f", cents / 100.0)
    end
  end
end
