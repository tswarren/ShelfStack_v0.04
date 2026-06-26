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
    @result = ItemSearch::Result.new(presenter: @item, match_type: "product")
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
  end

  test "returns batched operational summary for index row" do
    InventoryBalance.create!(store: @store, product_variant: @variant, quantity_on_hand: 3, quantity_available: 3, quantity_reserved: 0)

    summaries = Items::IndexOperationalSummary.for(
      store: @store,
      user: @user,
      results: [ @result ],
      warning_summaries: {}
    )

    summary = summaries.fetch(@item)
    assert_equal 3, summary.available
    assert summary.actions.any? { |action| action.label == "View" }
  end
end
