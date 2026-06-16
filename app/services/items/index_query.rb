# frozen_string_literal: true

module Items
  class IndexQuery
    Result = Struct.new(:results, :total_count, :page, :per_page, keyword_init: true)

    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100
    SEARCH_HIT_LIMIT = 500

    def self.call(**options)
      new(**options).call
    end

    def initialize(
      query: nil,
      format_id: nil,
      department_id: nil,
      sub_department_id: nil,
      store_category_id: nil,
      include_inactive: false,
      page: 1,
      per_page: DEFAULT_PER_PAGE
    )
      @query = query.to_s.strip
      @format_id = format_id.presence
      @department_id = department_id.presence
      @sub_department_id = sub_department_id.presence
      @store_category_id = store_category_id.presence
      @include_inactive = ActiveModel::Type::Boolean.new.cast(include_inactive)
      @page = [ page.to_i, 1 ].max
      @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    end

    def call
      entries = @query.present? ? search_entries : browse_entries
      total_count = entries.size
      offset = (@page - 1) * @per_page
      page_entries = entries.slice(offset, @per_page) || []

      Result.new(
        results: page_entries.map { |entry| build_result(entry) },
        total_count: total_count,
        page: @page,
        per_page: @per_page
      )
    end

    private

    def browse_entries
      entries = []
      entries.concat(catalog_browse_entries)
      entries.concat(non_catalog_browse_entries) if include_non_catalog_browse?
      sort_entries(entries)
    end

    def search_entries
      hits = []
      hits.concat(identifier_hits)
      hits.concat(catalog_item_hits)
      hits.concat(categorization_hits)
      hits.concat(product_hits)
      hits.concat(variant_hits)

      entries = dedupe_hits(hits)
      entries.select! { |entry| passes_filters?(entry) }
      sort_entries(entries)
    end

    def catalog_browse_entries
      catalog_item_scope
        .includes(:format, :catalog_item_identifiers, products: { cover_image_attachment: :blob, product_variants: %i[condition sub_department] })
        .map { |item| hit("catalog_item", item) }
    end

    def non_catalog_browse_entries
      non_catalog_product_scope
        .with_attached_cover_image
        .includes(product_variants: %i[condition sub_department])
        .map { |product| hit("product", product) }
    end

    def include_non_catalog_browse?
      @format_id.blank? && @store_category_id.blank?
    end

    def catalog_item_scope
      scope = CatalogItem.all
      scope = scope.active_records unless @include_inactive
      scope = scope.where(format_id: @format_id) if @format_id.present?
      scope = scope.where(store_category_id: resolved_store_category_ids) if resolved_store_category_ids.present?
      apply_classification_filter_to_catalog(scope)
    end

    def non_catalog_product_scope
      scope = Product.where(catalog_item_id: nil)
      scope = scope.active_records unless @include_inactive
      apply_classification_filter_to_products(scope)
    end

    def apply_classification_filter_to_catalog(scope)
      sub_department_ids = resolved_sub_department_ids
      return scope if sub_department_ids.blank?

      catalog_ids = catalog_ids_matching_classification(sub_department_ids)
      scope.where(id: catalog_ids)
    end

    def apply_classification_filter_to_products(scope)
      sub_department_ids = resolved_sub_department_ids
      return scope if sub_department_ids.blank?

      product_ids = non_catalog_product_ids_matching_classification(sub_department_ids)
      scope.where(id: product_ids)
    end

    def catalog_ids_matching_classification(sub_department_ids)
      variant_catalog_ids = CatalogItem.joins(products: :product_variants)
        .merge(classified_variant_scope.where(sub_department_id: sub_department_ids))
        .distinct
        .pluck(:id)

      default_catalog_ids = CatalogItem.joins(:products)
        .where(products: { default_sub_department_id: sub_department_ids })
        .distinct
        .pluck(:id)

      (variant_catalog_ids + default_catalog_ids).uniq
    end

    def non_catalog_product_ids_matching_classification(sub_department_ids)
      variant_product_ids = Product.where(catalog_item_id: nil)
        .joins(:product_variants)
        .merge(classified_variant_scope.where(sub_department_id: sub_department_ids))
        .distinct
        .pluck(:id)

      default_product_ids = Product.where(catalog_item_id: nil, default_sub_department_id: sub_department_ids)
        .pluck(:id)

      (variant_product_ids + default_product_ids).uniq
    end

    def classified_variant_scope
      @include_inactive ? ProductVariant.all : ProductVariant.active_records
    end

    def resolved_sub_department_ids
      if @sub_department_id.present?
        [ @sub_department_id.to_i ]
      elsif @department_id.present?
        SubDepartment.where(department_id: @department_id).pluck(:id)
      end
    end

    def resolved_store_category_ids
      return @resolved_store_category_ids if defined?(@resolved_store_category_ids)

      @resolved_store_category_ids = if @store_category_id.present?
                                       CategoryNode.descendant_ids_including_self(@store_category_id)
      end
    end

    def text_query
      @text_query ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    end

    def identifier_hits
      CatalogItemIdentifier.joins(:catalog_item)
        .merge(catalog_item_scope)
        .where("catalog_item_identifiers.normalized_identifier ILIKE ? OR catalog_item_identifiers.identifier_value ILIKE ?",
               text_query, text_query)
        .includes(catalog_item: [ :format, { products: { cover_image_attachment: :blob } }, :catalog_item_identifiers ])
        .limit(SEARCH_HIT_LIMIT)
        .map { |identifier| hit("catalog_item_identifier", identifier.catalog_item) }
    end

    def catalog_item_hits
      catalog_item_scope
        .includes(:format, :catalog_item_identifiers, products: { cover_image_attachment: :blob, product_variants: %i[condition sub_department] })
        .where(catalog_item_text_conditions, *Array.new(10, text_query))
        .limit(SEARCH_HIT_LIMIT)
        .map { |item| hit("catalog_item", item) }
    end

    def catalog_item_text_conditions
      <<~SQL.squish
        catalog_items.title ILIKE ? OR
        catalog_items.creators ILIKE ? OR
        catalog_items.publisher ILIKE ? OR
        catalog_items.series_name ILIKE ? OR
        catalog_items.series_enumeration ILIKE ? OR
        catalog_items.bisac_subjects ILIKE ? OR
        catalog_items.genres ILIKE ? OR
        catalog_items.themes ILIKE ? OR
        catalog_items.target_audiences ILIKE ? OR
        catalog_items.description ILIKE ?
      SQL
    end

    def categorization_hits
      CatalogItem.joins(categorizations: :category_node)
        .merge(catalog_item_scope)
        .includes(:format, :catalog_item_identifiers, products: { cover_image_attachment: :blob, product_variants: %i[condition sub_department] })
        .where("category_nodes.name ILIKE ?", text_query)
        .distinct
        .limit(SEARCH_HIT_LIMIT)
        .map { |item| hit("catalog_item", item) }
    end

    def product_hits
      product_scope = Product.all
      product_scope = product_scope.active_records unless @include_inactive
      product_scope.where("sku ILIKE ? OR name ILIKE ?", text_query, text_query)
        .with_attached_cover_image
        .includes(:catalog_item, product_variants: %i[condition sub_department])
        .limit(SEARCH_HIT_LIMIT)
        .map { |product| hit("product", product) }
    end

    def variant_hits
      variant_scope = classified_variant_scope
        .where("sku ILIKE ? OR name ILIKE ?", text_query, text_query)
        .includes(product: [ :catalog_item, { cover_image_attachment: :blob } ], condition: nil, sub_department: nil)
        .limit(SEARCH_HIT_LIMIT)
        .map { |variant| hit("product_variant", variant) }
    end

    def hit(match_type, record)
      entry(match_type, record, sort_key_for(record, match_type))
    end

    def entry(match_type, record, sort_key)
      { match_type: match_type, record: record, sort_key: sort_key.to_s.downcase }
    end

    def sort_key_for(record, match_type)
      case match_type
      when "catalog_item", "catalog_item_identifier"
        record.is_a?(CatalogItem) ? record.title : record.catalog_item&.title
      when "product", "product_variant"
        record.is_a?(Product) ? record.name : record.product&.name
      else
        record.try(:title) || record.try(:name)
      end
    end

    def dedupe_hits(hits)
      hits.each_with_object({}) do |entry, memo|
        presenter = presenter_for(entry)
        key = dedupe_key(presenter)
        memo[key] ||= entry
      end.values
    end

    def dedupe_key(presenter)
      if presenter.catalog_item.present?
        [ :catalog, presenter.catalog_item.id ]
      else
        [ :product, presenter.product&.id ]
      end
    end

    def passes_filters?(entry)
      presenter = presenter_for(entry)

      if @format_id.present?
        return false if presenter.catalog_item.blank?
        return false unless presenter.catalog_item.format_id == @format_id.to_i
      end

      if resolved_store_category_ids.present?
        return false if presenter.catalog_item.blank?
        return false unless presenter.catalog_item.store_category_id.in?(resolved_store_category_ids)
      end

      sub_department_ids = resolved_sub_department_ids
      return true if sub_department_ids.blank?

      matches_classification?(presenter, sub_department_ids)
    end

    def matches_classification?(presenter, sub_department_ids)
      product = presenter.product
      return false if product.blank?

      return true if product.default_sub_department_id.in?(sub_department_ids)

      variants = @include_inactive ? product.product_variants : product.product_variants.active_records
      variants.any? { |variant| variant.sub_department_id.in?(sub_department_ids) }
    end

    def sort_entries(entries)
      entries.sort_by { |entry| entry[:sort_key] }
    end

    def presenter_for(entry)
      case entry[:match_type]
      when "catalog_item", "catalog_item_identifier"
        record = entry[:record].is_a?(CatalogItem) ? entry[:record] : entry[:record].catalog_item
        Items::ItemPresenter.from_catalog_item(record)
      when "product"
        Items::ItemPresenter.from_product(entry[:record])
      when "product_variant"
        Items::ItemPresenter.from_product_variant(entry[:record])
      else
        raise ArgumentError, "Unknown entry type: #{entry[:match_type]}"
      end
    end

    def build_result(entry)
      ItemSearch::Result.new(presenter: presenter_for(entry), match_type: entry[:match_type])
    end
  end
end
