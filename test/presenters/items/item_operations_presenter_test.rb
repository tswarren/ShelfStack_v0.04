# frozen_string_literal: true

require "test_helper"

class ItemOperationsPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper
  include V0047TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @user
    )
    @product = @variant.product
    create_hold_with_on_hand_allocation!(store: @store, actor: @user, variant: @variant, quantity: 2)
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
    assert row.demand_actions.map(&:drawer_key).include?("manual_tbo")
  end

  test "ready_for_pickup_qty uses active on-hand allocation quantity" do
    presenter = Items::ItemOperationsPresenter.new(
      item: Items::ItemPresenter.from_product(@product),
      store: @store,
      user: @user
    )
    row = presenter.variant_rows.find { |candidate| candidate.variant.id == @variant.id }

    assert_equal 2, row.ready_for_pickup_qty
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
