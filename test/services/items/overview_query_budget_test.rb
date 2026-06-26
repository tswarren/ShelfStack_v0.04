# frozen_string_literal: true

require "test_helper"

class Items::OverviewQueryBudgetTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @sub_department = create_product_variant!(product: @product).sub_department
    9.times do |index|
      create_product_variant!(
        product: @product,
        sub_department: @sub_department,
        sku: "#{@product.sku}-V#{index + 2}"
      )
    end
    @item = Items::ItemPresenter.from_product(@product.reload)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    grant_permission!(@user, "pos.transactions.view", store: @store)
  end

  test "overview batches order eligibility across variants" do
    resolver_calls = 0
    original = Purchasing::OrderEligibilityResolver.method(:for_variants)
    Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants) do |**args|
      resolver_calls += 1
      original.call(**args)
    end

    begin
      overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
      overview.warnings
      overview.matrix_rows
      overview.summary_cards
    ensure
      Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants, original)
    end

    assert_equal 1, resolver_calls
  end
end
