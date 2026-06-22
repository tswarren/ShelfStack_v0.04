# frozen_string_literal: true

require "test_helper"

class CustomerRequestsSurfaceNotifyLinesTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "notify", provisional_title: "Notify book" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
  end

  test "surfaces matched notify line when stock is available" do
    CustomerRequests::SurfaceNotifyLines.for_variant(store: @store, variant: @variant, actor: @user)

    assert_equal "ready_for_pickup", @line.reload.status
  end

  test "does not surface when no stock available" do
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update!(quantity_on_hand: 0, quantity_available: 0)

    CustomerRequests::SurfaceNotifyLines.for_variant(store: @store, variant: @variant, actor: @user)

    assert_equal "matched", @line.reload.status
  end
end
