# frozen_string_literal: true

require "test_helper"

class CustomerRequestsStartFromItemTest < ActiveSupport::TestCase
  include Phase2TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!(display_name: "Hold Pat")
  end

  test "creates hold with matched line and reservation" do
    result = CustomerRequests::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      request_type: "hold",
      quantity: 1,
      customer: @customer,
      expires_at: 7.days.from_now
    )

    assert_equal "hold", result.line.request_type
    assert_equal @variant.id, result.line.product_variant_id
    assert_equal "ready_for_pickup", result.line.reload.status
    assert_not_nil result.reservation
    assert_equal 1, result.reservation.quantity_reserved
  end

  test "creates notify request without reservation" do
    result = CustomerRequests::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      request_type: "notify",
      quantity: 1,
      customer_name_snapshot: "Walk-in Notify"
    )

    assert_equal "notify", result.line.request_type
    assert_equal "matched", result.line.status
    assert_nil result.reservation
    assert_nil result.special_order
  end

  test "rejects special order for used-like variant" do
    used = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_cr", name: "Used Good", short_name: "Used", new_condition: false, buyback_eligible: true)
    @variant.update!(condition: used, orderable: false)

    error = assert_raises(CustomerRequests::StartFromItem::StartError) do
      CustomerRequests::StartFromItem.call!(
        store: @store,
        variant: @variant.reload,
        actor: @user,
        request_type: "special_order",
        quantity: 1,
        customer: @customer
      )
    end

    assert_match(/used-like/i, error.message)
  end

  test "creates special order for linked customer" do
    result = CustomerRequests::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      request_type: "special_order",
      quantity: 2,
      customer: @customer
    )

    assert_equal "special_order", result.line.request_type
    assert_not_nil result.special_order
    assert_equal "approved", result.special_order.status
    assert_equal 2, result.special_order.quantity_committed
  end

  test "rejects special order without customer record" do
    assert_raises(CustomerRequests::StartFromItem::StartError) do
      CustomerRequests::StartFromItem.call!(
        store: @store,
        variant: @variant,
        actor: @user,
        request_type: "special_order",
        quantity: 1,
        customer_name_snapshot: "Walk-in Only"
      )
    end
  end

  test "hold supports override when authorized" do
    result = CustomerRequests::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      request_type: "hold",
      quantity: 5,
      customer: @customer,
      override_authorized_by_user: @user,
      override_reason: "Customer prepaid"
    )

    assert_equal 5, result.reservation.quantity_reserved
  end
end
