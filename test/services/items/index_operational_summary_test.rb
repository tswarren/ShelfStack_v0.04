# frozen_string_literal: true

require "test_helper"

class Items::IndexOperationalSummaryTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 4,
      quantity_available: 4
    )
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 3,
      status: "open"
    )
    @result = ItemSearch::Result.new(presenter: @item, match_type: "product")
  end

  test "summarizes stock and order signals per item presenter" do
    summaries = Items::IndexOperationalSummary.for(
      store: @store,
      user: @user,
      results: [ @result ]
    )

    summary = summaries[@item]
    assert_equal 4, summary.available
    assert_equal 3, summary.open_tbo
    assert summaries[@item].actions.any? { |action| action.label == "View" }
  end
end
