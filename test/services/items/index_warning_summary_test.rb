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

  test "batches warnings across multiple index rows" do
    sub_department = @variant.sub_department
    results = 3.times.map do
      product = create_product!(sku: "IDX-WARN-#{SecureRandom.hex(3)}")
      create_product_variant!(product: product, sub_department: sub_department, sku: "#{product.sku}-NEW")
      ItemSearch::Result.new(presenter: Items::ItemPresenter.from_product(product), match_type: "product")
    end

    resolver_calls = 0
    original = Purchasing::OrderEligibilityResolver.method(:for_variants)
    Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants) do |**args|
      resolver_calls += 1
      original.call(**args)
    end

    begin
      summaries = Items::IndexWarningSummary.for(store: @store, user: @user, results: results)
    ensure
      Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants, original)
    end

    assert_equal 3, summaries.size
    assert_equal 1, resolver_calls
  end
end
