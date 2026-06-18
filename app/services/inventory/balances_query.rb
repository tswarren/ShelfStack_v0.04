# frozen_string_literal: true

module Inventory
  class BalancesQuery
    Result = Struct.new(:balances, :total_count, :page, :per_page, keyword_init: true)

    DEFAULT_PER_PAGE = 50
    MAX_PER_PAGE = 100
    LOW_STOCK_THRESHOLD = 5

    def self.call(store:, query: nil, page: 1, per_page: DEFAULT_PER_PAGE, stock_filter: nil)
      new(store:, query:, page:, per_page:, stock_filter:).call
    end

    def initialize(store:, query: nil, page: 1, per_page: DEFAULT_PER_PAGE, stock_filter: nil)
      @store = store
      @query = query.to_s.strip
      @page = [ page.to_i, 1 ].max
      @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
      @stock_filter = stock_filter.to_s.presence
    end

    def call
      scope = InventoryBalance
        .includes(product_variant: :product)
        .where(store: store)
        .joins(:product_variant)
        .order("product_variants.sku")

      if query.present?
        q = "%#{query}%"
        scope = scope.where("product_variants.sku ILIKE :q OR product_variants.name ILIKE :q", q: q)
      end

      scope = apply_stock_filter(scope)

      total_count = scope.count
      balances = scope.offset((page - 1) * per_page).limit(per_page)

      Result.new(balances: balances, total_count: total_count, page: page, per_page: per_page)
    end

    private

    attr_reader :store, :query, :page, :per_page, :stock_filter

    def apply_stock_filter(scope)
      case stock_filter
      when "zero"
        scope.where("inventory_balances.quantity_on_hand <= 0")
      when "low"
        scope.where("inventory_balances.quantity_on_hand > 0 AND inventory_balances.quantity_on_hand <= ?", LOW_STOCK_THRESHOLD)
      else
        scope
      end
    end
  end
end
