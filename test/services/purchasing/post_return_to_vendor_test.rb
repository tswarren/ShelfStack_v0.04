# frozen_string_literal: true

require "test_helper"

class Purchasing::PostReturnToVendorTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 10, unit_cost_cents: 800)
  end

  test "posts return and reduces on-hand balance" do
    rtv = create_return_to_vendor!(
      store: @store,
      vendor: @vendor,
      lines: [{ product_variant: @variant, quantity: 3 }]
    )

    Purchasing::PostReturnToVendor.call(return_to_vendor: rtv, posted_by_user: @user)

    assert_equal "posted", rtv.reload.status
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 7, balance.quantity_on_hand
    assert AuditEvent.exists?(event_name: "return_to_vendor.posted", auditable: rtv)
  end

  test "rejects non-returnable variant for vendor" do
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      returnability_status: "non_returnable",
      active: true
    )
    rtv = create_return_to_vendor!(
      store: @store,
      vendor: @vendor,
      lines: [{ product_variant: @variant, quantity: 1 }]
    )

    error = assert_raises(Purchasing::PostReturnToVendor::PostingError) do
      Purchasing::PostReturnToVendor.call(return_to_vendor: rtv, posted_by_user: @user)
    end
    assert_match(/not returnable/i, error.message)
  end
end
