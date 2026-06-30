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
      needs_review_intake: false,
      page: 1,
      per_page: DEFAULT_PER_PAGE
    )
      @query = query.to_s.strip
      @format_id = format_id.presence
      @department_id = department_id.presence
      @sub_department_id = sub_department_id.presence
      @store_category_id = store_category_id.presence
      @include_inactive = ActiveModel::Type::Boolean.new.cast(include_inactive)
      @needs_review_intake = ActiveModel::Type::Boolean.new.cast(needs_review_intake)
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
      product_browse_scope
        .with_attached_cover_image
        .includes(:format, product_variants: %i[condition sub_department])
        .map { |product| hit("product", product) }
        .then { |entries| sort_entries(entries) }
    end

    def search_entries
      hits = []
      hits.concat(identifier_hits)
      hits.concat(product_metadata_hits)
      hits.concat(categorization_hits)
      hits.concat(product_hits)
      hits.concat(variant_hits)

      entries = dedupe_hits(hits)
      entries.select! { |entry| passes_filters?(entry) }
      sort_entries(entries)
    end

    def product_browse_scope
      scope = Product.all
      scope = scope.active_records unless @include_inactive
      scope = scope.where(source: "buyback_intake", needs_review: true) if @needs_review_intake
      scope = scope.where(format_id: @format_id) if @format_id.present?
      scope = scope.where(store_category_id: resolved_store_category_ids) if resolved_store_category_ids.present?
      apply_classification_filter_to_products(scope)
    end

    def apply_classification_filter_to_products(scope)
      sub_department_ids = resolved_sub_department_ids
      return scope if sub_department_ids.blank?

      product_ids = product_ids_matching_classification(sub_department_ids)
      scope.where(id: product_ids)
    end

    def product_ids_matching_classification(sub_department_ids)
      variant_product_ids = Product.joins(:product_variants)
        .merge(classified_variant_scope.where(sub_department_id: sub_department_ids))
        .distinct
        .pluck(:id)

      default_product_ids = Product.where(default_sub_department_id: sub_department_ids).pluck(:id)

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
      LegacyProductIdentifierBridge.find_products_by_identifier_query(@query, active_only: !@include_inactive)
        .merge(product_browse_scope)
        .with_attached_cover_image
        .includes(:format, product_variants: %i[condition sub_department])
        .limit(SEARCH_HIT_LIMIT)
        .map { |product| hit("product_identifier", product) }
    end

    def product_metadata_hits
      product_browse_scope
        .with_attached_cover_image
        .includes(:format, product_variants: %i[condition sub_department])
        .where(product_text_conditions, *Array.new(10, text_query))
        .limit(SEARCH_HIT_LIMIT)
        .map { |product| hit("product", product) }
    end

    def product_text_conditions
      <<~SQL.squish
        products.title ILIKE ? OR
        products.name ILIKE ? OR
        products.creators ILIKE ? OR
        products.publisher ILIKE ? OR
        products.series_name ILIKE ? OR
        products.series_enumeration ILIKE ? OR
        products.bisac_subjects ILIKE ? OR
        products.genres ILIKE ? OR
        products.themes ILIKE ? OR
        products.description ILIKE ?
      SQL
    end

    def categorization_hits
      Product.joins(categorizations: :category_node)
        .merge(product_browse_scope)
        .with_attached_cover_image
        .includes(:format, product_variants: %i[condition sub_department])
        .where("category_nodes.name ILIKE ?", text_query)
        .distinct
        .limit(SEARCH_HIT_LIMIT)
        .map { |product| hit("product", product) }
    end

    def product_hits
      product_browse_scope
        .where("products.sku ILIKE ?", text_query)
        .with_attached_cover_image
        .includes(:format, product_variants: %i[condition sub_department])
        .limit(SEARCH_HIT_LIMIT)
        .map { |product| hit("product", product) }
    end

    def variant_hits
      classified_variant_scope
        .where("sku ILIKE ? OR name ILIKE ?", text_query, text_query)
        .includes(product: { cover_image_attachment: :blob }, condition: nil, sub_department: nil)
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
      when "product", "product_identifier"
        record.title.presence || record.name
      when "product_variant"
        record.product&.title.presence || record.product&.name || record.name
      else
        record.try(:title) || record.try(:name)
      end
    end

    def dedupe_hits(hits)
      hits.each_with_object({}) do |entry, memo|
        presenter = presenter_for(entry)
        key = [ :product, presenter.product&.id ]
        memo[key] ||= entry if key.last.present?
      end.values
    end

    def passes_filters?(entry)
      presenter = presenter_for(entry)
      product = presenter.product
      return false if product.blank?

      if @needs_review_intake
        return false unless product.source == "buyback_intake" && product.needs_review?
      end

      if @format_id.present?
        return false unless product.format_id == @format_id.to_i
      end

      if resolved_store_category_ids.present?
        return false unless product.store_category_id.in?(resolved_store_category_ids)
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
      when "product", "product_identifier"
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
