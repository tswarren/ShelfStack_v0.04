# frozen_string_literal: true

class ItemSearch
  Result = Struct.new(:presenter, :match_type, keyword_init: true)

  def self.call(query:, limit: 50)
    new(query: query, limit: limit).call
  end

  def initialize(query:, limit: 50)
    @query = query.to_s.strip
    @limit = limit
  end

  def call
    return [] if @query.blank?

    hits = []
    hits.concat(identifier_hits)
    hits.concat(catalog_item_hits)
    hits.concat(product_hits)
    hits.concat(variant_hits)
    dedupe_presenters(hits).first(@limit)
  end

  private

  def normalized_query
    @normalized_query ||= @query.upcase.gsub(/[^0-9A-Z]/, "")
  end

  def text_query
    @text_query ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
  end

  def identifier_hits
    CatalogItemIdentifier.active_records
      .where("normalized_identifier ILIKE ? OR identifier_value ILIKE ?", text_query, text_query)
      .includes(catalog_item: [ :format, { products: { cover_image_attachment: :blob } }, :catalog_item_identifiers ])
      .limit(@limit)
      .map { |identifier| hit("catalog_item_identifier", identifier) }
  end

  def catalog_item_hits
    CatalogItem.active_records
      .where("title ILIKE ? OR creators ILIKE ? OR publisher ILIKE ?", text_query, text_query, text_query)
      .includes(:format, :catalog_item_identifiers, products: { cover_image_attachment: :blob })
      .limit(@limit)
      .map { |item| hit("catalog_item", item) }
  end

  def product_hits
    Product.active_records
      .where("sku ILIKE ? OR name ILIKE ?", text_query, text_query)
      .with_attached_cover_image
      .includes(:catalog_item, product_variants: %i[condition sub_department])
      .limit(@limit)
      .map { |product| hit("product", product) }
  end

  def variant_hits
    ProductVariant.active_records
      .where("sku ILIKE ? OR name ILIKE ?", text_query, text_query)
      .includes(product: [ :catalog_item, { cover_image_attachment: :blob } ], condition: nil, sub_department: nil)
      .limit(@limit)
      .map { |variant| hit("product_variant", variant) }
  end

  def hit(record_type, record)
    { record_type: record_type, record: record }
  end

  def dedupe_presenters(hits)
    hits.each_with_object({}) do |hit, memo|
      presenter = Items::ItemPresenter.from_search_hit(hit)
      key = [ presenter.catalog_item&.id, presenter.product&.id ]
      memo[key] ||= Result.new(presenter: presenter, match_type: hit[:record_type])
    end.values
  end
end
