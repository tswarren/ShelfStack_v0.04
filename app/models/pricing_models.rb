# frozen_string_literal: true

module PricingModels
  PRICING_MODELS = %w[
    trade_discount
    trade_discount_returnable
    short_discount
    net_cost_markup
    blended_lot_cost
    buyback_resale
    recipe_cost
    pass_through
    markdown
  ].freeze
end
