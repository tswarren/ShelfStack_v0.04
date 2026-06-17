# frozen_string_literal: true

module Inventory
  class VariantLookupPresenter
    def self.as_json(result, store:, vendor: nil)
      new(result, store:, vendor:).as_json
    end

    def initialize(result, store:, vendor: nil)
      @result = result
      @store = store
      @vendor = vendor
    end

    def as_json
      {
        status: result.status.to_s,
        message: result.message,
        variants: result.variants.map { |variant| variant_json(variant) }
      }
    end

    private

    attr_reader :result, :store, :vendor

    def variant_json(variant)
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      json = {
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        condition: variant.condition&.short_name,
        inventory_behavior: variant.inventory_behavior,
        eligible: Inventory::Eligibility.eligible?(variant),
        quantity_on_hand: balance&.quantity_on_hand || 0
      }

      if vendor.present?
        defaults = Purchasing::LinePriceDefaults.resolve(variant: variant, vendor: vendor)
        json[:unit_list_price_cents] = defaults.unit_list_price_cents
        json[:supplier_discount_bps] = defaults.supplier_discount_bps
        json[:unit_cost_cents] = defaults.unit_cost_cents
      end

      json
    end
  end
end
