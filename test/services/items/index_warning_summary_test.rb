# frozen_string_literal: true

require "test_helper"

class Items::IndexWarningSummaryTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @variant = create_product_variant!(product: @product, selling_price_cents: 0)
    @item = Items::ItemPresenter.from_product(@product)
    @result = ItemSearch::Result.new(presenter: @item, match_type: "product")
    grant_all_phase5_permissions!(@user, store: @store)
  end

  test "returns worst severity and counts per item presenter" do
    summaries = Items::IndexWarningSummary.for(store: @store, user: @user, results: [ @result ])

    summary = summaries.fetch(@item)
    assert summary.warning_count.positive?
    assert_includes %i[blocking warning info], summary.worst_severity
    assert summary.counts_by_severity.values.sum == summary.warning_count
  end
end
