# frozen_string_literal: true

require "test_helper"

class DemandLinesStartFromItemTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @customer = create_customer!(display_name: "Item Customer")
  end

  test "start from item creates demand line only" do
    assert_difference -> { DemandLine.count }, 1 do
      assert_no_difference [ -> { CustomerRequest.count }, -> { SpecialOrder.count } ] do
        DemandLines::StartFromItem.call!(
          store: @store,
          variant: @variant,
          actor: @user,
          capture_intent: "hold",
          customer: @customer
        )
      end
    end
  end
end
