# frozen_string_literal: true

require "test_helper"

class PurchaseRequestLineTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @request = PurchaseRequest.create!(store: @store, status: "open")
    @line = @request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 10,
      status: "open"
    )
  end

  test "open_remaining_quantities_for sums remaining not requested quantity" do
    create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 4,
          purchase_request_line: @line
        )
      ]
    )

    quantities = PurchaseRequestLine.open_remaining_quantities_for(store: @store, variant_ids: [ @variant.id ])

    assert_equal 6, quantities.fetch(@variant.id)
  end
end
