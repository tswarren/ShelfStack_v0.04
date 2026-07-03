# frozen_string_literal: true

require "test_helper"

class SourcingNextActionPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!(availability_workflow: "order_to_confirm")
    @variant = create_product_variant!
    @demand = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: create_customer!,
      quantity: 1
    )
  end

  test "order_to_confirm vendor yields order to confirm label" do
    action = Sourcing::NextActionPresenter.call(demand_line: @demand, vendor: @vendor)

    assert_equal "order_to_confirm", action.next_action_key
    assert_equal "Order to confirm", action.next_action_label
  end

  test "manual_review vendor yields record manual response label" do
    @vendor.update!(availability_workflow: "manual_review")
    action = Sourcing::NextActionPresenter.call(demand_line: @demand, vendor: @vendor)

    assert_equal "record_manual_response", action.next_action_key
    assert_equal "Record manual response", action.next_action_label
  end
end
