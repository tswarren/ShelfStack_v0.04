# frozen_string_literal: true

require "test_helper"

class ItemsCustomerDemandOperationsTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "customer_requests.access", store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @user
    )
    @product = @variant.product
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "hold", provisional_title: "Ops hold" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer_request_line: @line
    )
  end

  test "operations tab presenter includes customer demand sections" do
    presenter = Items::ItemOperationsTabPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )

    assert presenter.customer_demand_visible?
    assert_includes presenter.open_customer_request_lines.map(&:id), @line.id
  end
end
