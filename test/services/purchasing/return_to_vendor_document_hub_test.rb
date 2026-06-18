# frozen_string_literal: true

require "test_helper"

class Purchasing::ReturnToVendorDocumentHubTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @rtv = create_return_to_vendor!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          quantity: 2,
          unit_cost_cents: 500,
          credit_amount_cents: 1000
        }
      ]
    )
  end

  test "summarizes line totals" do
    hub = Purchasing::ReturnToVendorDocumentHub.call(@rtv)

    assert_equal 2, hub.totals.units
    assert_equal 1000, hub.totals.total_credit_cents
    assert_equal 1000, hub.totals.total_cost_cents
    assert_nil hub.inventory_posting
  end
end
