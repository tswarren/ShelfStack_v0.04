# frozen_string_literal: true

require "test_helper"

class Items::ItemOverviewPresenterTest < ActiveSupport::TestCase
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
    assert_includes %i[present warning missing], matrix_row.vendor_source_status
  end
end
