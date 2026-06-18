# frozen_string_literal: true

require "test_helper"

class Items::ItemOperationsPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
  end

  test "rollup metrics summarize variant operational quantities" do
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 6,
      quantity_available: 6
    )
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )

    presenter = Items::ItemOperationsPresenter.new(item: @item, store: @store, user: @user)
    metrics = presenter.rollup_metrics.index_by(&:label)

    assert_equal 6, metrics["On hand"].value
    assert_equal 6, metrics["Available"].value
    assert_equal 2, metrics["TBO"].value
  end

  test "flags missing vendor source on variant row" do
    presenter = Items::ItemOperationsPresenter.new(item: @item, store: @store, user: @user)
    row = presenter.variant_rows.first

    assert_nil row.preferred_vendor_name
    assert_nil row.vendor_item_number
  end
end
