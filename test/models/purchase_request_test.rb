# frozen_string_literal: true

require "test_helper"

class PurchaseRequestTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @user = create_user!
    Current.store = @store
  end

  test "creating purchase request does not change inventory" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 5,
      request_reason: "tbo",
      status: "open"
    )

    assert_equal 0, InventoryBalance.where(store: @store, product_variant: @variant).count
    assert_equal 0, InventoryPosting.count
  end
end
