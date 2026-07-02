# frozen_string_literal: true

require "test_helper"

class VendorResponseTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant)
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 3)
    @attempt = Sourcing::CreateAttempt.call!(
      sourcing_run: @run,
      actor: @user,
      vendor: @vendor,
      quantity: 3
    )
  end

  test "final response requires full quantity split" do
    response = VendorResponse.new(
      store: @store,
      sourcing_attempt: @attempt,
      vendor: @vendor,
      response_status: "partially_confirmed",
      response_method: "manual",
      responded_by_user: @user,
      responded_at: Time.current,
      quantity_confirmed: 1,
      quantity_backordered: 1,
      final_response: true
    )

    assert_not response.valid?
    assert_includes response.errors[:base], "final response quantity total must equal attempt quantity requested"
  end

  test "valid final response when split equals attempt quantity" do
    response = VendorResponse.new(
      store: @store,
      sourcing_attempt: @attempt,
      vendor: @vendor,
      response_status: "partially_confirmed",
      response_method: "manual",
      responded_by_user: @user,
      responded_at: Time.current,
      quantity_confirmed: 1,
      quantity_backordered: 1,
      quantity_unavailable: 1,
      final_response: true
    )

    assert response.valid?
  end
end
