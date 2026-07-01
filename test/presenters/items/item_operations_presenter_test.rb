# frozen_string_literal: true

require "test_helper"

class ItemOperationsPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "customer_requests.access", store: @store)
    grant_permission!(@user, "customer_requests.create", store: @store)
    grant_permission!(@user, "inventory_reservations.create", store: @store)
    grant_permission!(@user, "special_orders.create", store: @store)
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
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 2,
      reserved_by_user: @user,
      customer_request_line: @line
    )
    @reservation.update!(status: "ready", quantity_fulfilled: 1)
  end

  test "variant row includes customer demand actions" do
    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )
    row = presenter.variant_rows.find { |candidate| candidate.variant.id == @variant.id }

    assert row.demand_actions.map(&:drawer_key).include?("hold")
    assert row.demand_actions.map(&:drawer_key).include?("notify")
    assert row.demand_actions.map(&:drawer_key).include?("special_order")
  end

  test "ready_for_pickup_qty uses reservation remaining quantity" do
    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )
    row = presenter.variant_rows.find { |candidate| candidate.variant.id == @variant.id }

    assert_equal 1, row.ready_for_pickup_qty
  end

  test "non-inventory variant omits order action" do
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)
    @variant.update!(inventory_behavior: "digital_asset")

    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )
    row = presenter.variant_rows.find { |candidate| candidate.variant.id == @variant.id }

    refute row.actions.map(&:label).include?("Order")
  end

  test "header add to po requires inventory eligible variant" do
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)
    @variant.update!(inventory_behavior: "digital_asset")

    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )

    refute presenter.header_actions.map(&:label).include?("Add to PO")
  end

  test "header omits mark tbo and add to po when only used-like inventory-eligible variant exists" do
    grant_permission!(@user, "orders.purchase_requests.create", store: @store)
    grant_permission!(@user, "orders.purchase_orders.create", store: @store)
    grant_permission!(@user, "orders.returns_to_vendor.create", store: @store)

    used = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_header", name: "Used Good", short_name: "Used", new_condition: false, buyback_eligible: true)
    @variant.update!(condition: used, orderable: false, inventory_behavior: "standard_physical")

    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )
    labels = presenter.header_actions.map(&:label)

    refute_includes labels, "Mark TBO"
    refute_includes labels, "Add to PO"
    assert_includes labels, "RTV"
  end
end
