# frozen_string_literal: true

require "test_helper"

class Items::ItemOverviewPresenterTest < ActiveSupport::TestCase
  include Phase3TestHelper

  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!(list_price_cents: 2000)
    @variant = create_product_variant!(product: @product, inventory_behavior: "standard_physical", selling_price_cents: 1599)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
  end

  test "summary cards and matrix rows include operational fields" do
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 5,
      quantity_available: 5,
      quantity_reserved: 0
    )

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    cards = overview.summary_cards

    assert cards.any? { |card| card.key == :sell }
    assert cards.any? { |card| card.key == :order }
    assert cards.any? { |card| card.key == :stock }

    matrix_row = overview.matrix_rows.first
    assert_equal @variant, matrix_row.variant
    assert_equal 5, matrix_row.snapshot.on_hand
    assert_includes %i[present warning missing not_applicable], matrix_row.vendor_source_status
    assert_equal @variant.sub_department.name, matrix_row.sub_department_name
    assert_equal @variant.sub_department.default_tax_category.name, matrix_row.tax_category_name
  end

  test "summary cards report not set up when no active variants" do
    product = create_product!(sku: "NO-VAR-#{SecureRandom.hex(3)}")
    item = Items::ItemPresenter.from_product(product)

    overview = Items::ItemOverviewPresenter.for(item: item, store: @store, user: @user)
    sell = overview.summary_cards.find { |card| card.key == :sell }
    order = overview.summary_cards.find { |card| card.key == :order }

    assert_equal "Not set up", sell.status
    assert_equal "No active sellable SKUs", sell.detail
    refute_equal "Ready", sell.status

    assert_equal "Not set up", order.status
    assert_equal "No active sellable SKUs", order.detail
    refute_match(/0\/0/, order.detail)
  end

  test "stock card reflects availability state" do
    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    stock = overview.summary_cards.find { |card| card.key == :stock }

    assert_equal "No stock", stock.status

    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 5,
      quantity_available: 3,
      quantity_reserved: 2
    )

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    stock = overview.summary_cards.find { |card| card.key == :stock }

    assert_equal "Available", stock.status
  end

  test "sales history hidden without pos transaction view permission" do
    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)

    assert_empty overview.sales_history_rows
    refute overview.sales_visible?
  end

  test "sales history visible with pos transaction view permission" do
    grant_permission!(@user, "pos.transactions.view", store: @store)

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)

    assert overview.sales_visible?
  end

  test "used variant vendor source status is not applicable" do
    used = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_used", name: "Used Good", short_name: "Used", new_condition: false, buyback_eligible: true)
    @variant.update!(condition: used, orderable: false)

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    matrix_row = overview.matrix_rows.find { |row| row.variant.id == @variant.id }

    assert_equal :not_applicable, matrix_row.vendor_source_status
  end

  test "summary strip rolls up availability and activity dates" do
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 8,
      quantity_available: 6,
      quantity_reserved: 2
    )

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    strip = overview.summary_strip

    assert_equal 6, strip.available
    assert_equal 2, strip.reserved
  end

  test "availability rows include resolved subdepartment and demand actions" do
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)

    overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
    row = overview.availability_rows.first

    assert_equal @variant, row.variant
    assert_equal @variant.sub_department.name, row.resolved_subdepartment_name
    assert row.demand_actions.any?
  end
end
