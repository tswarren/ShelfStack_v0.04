# frozen_string_literal: true

module AddItem
  class DefaultSellingPrice
    def self.cents(product:, condition: nil)
      list_price = product.list_price_cents.to_i
      return list_price unless product.variation_type == "conditional" && condition.present?

      factor = condition.default_list_price_factor_bps.to_i
      (list_price * factor) / 10_000
    end
  end
end
