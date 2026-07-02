# frozen_string_literal: true

require "test_helper"

class Items::IndexOperationalSummaryTest < ActiveSupport::TestCase
  include V0047TestHelper

  setup do
    seed_phase5_reference_data!
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
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

  test "uses shared variant snapshot for multiple index rows" do
    sub_department = @variant.sub_department
    results = 2.times.map do
      product = create_product!(sku: "IDX-OPS-#{SecureRandom.hex(3)}")
      create_product_variant!(product: product, sub_department: sub_department, sku: "#{product.sku}-NEW")
      ItemSearch::Result.new(presenter: Items::ItemPresenter.from_product(product), match_type: "product")
    end

    snapshot_calls = 0
    original = Items::VariantOperationalSnapshot.method(:for_variants)
    Items::VariantOperationalSnapshot.singleton_class.define_method(:for_variants) do |**args|
      snapshot_calls += 1
      original.call(**args)
    end

    begin
      Items::IndexOperationalSummary.for(
        store: @store,
        user: @user,
        results: results,
        warning_summaries: {}
      )
    ensure
      Items::VariantOperationalSnapshot.singleton_class.define_method(:for_variants, original)
    end

    assert_equal 1, snapshot_calls
  end

  test "includes manual tbo action for vendor-orderable variants" do
    InventoryBalance.create!(store: @store, product_variant: @variant, quantity_on_hand: 1, quantity_available: 1, quantity_reserved: 0)
    grant_permission!(@user, "demand.create", store: @store)

    summaries = Items::IndexOperationalSummary.for(
      store: @store,
      user: @user,
      results: [ @result ],
      warning_summaries: {}
    )

    tbo_action = summaries.fetch(@item).actions.find { |action| action.label == "TBO" }
    assert_includes tbo_action.url, "capture_intent=manual_tbo"
    assert_includes tbo_action.url, "product_variant_id=#{@variant.id}"
  end
end
