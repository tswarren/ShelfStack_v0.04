# frozen_string_literal: true

require "test_helper"

class Items::ItemOperationsTabPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    seed_phase5_reference_data!
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    grant_permission!(@user, "demand.access", store: @store)
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @item = Items::ItemPresenter.from_product(@product)
    create_manual_tbo_demand!(store: @store, actor: @user, variant: @variant, quantity: 3)
  end

  test "metrics include open manual tbo count for item variants" do
    presenter = Items::ItemOperationsTabPresenter.new(
      item: @item,
      store: @store,
      user: @user
    )

    tbo_metric = presenter.metrics.find { |metric| metric[:label] == "Open TBO" }
    assert_equal 1, tbo_metric[:value]
    assert_equal 1, presenter.open_manual_tbo_demand_lines.size
    assert_equal presenter.open_manual_tbo_demand_lines, presenter.open_purchase_request_lines
  end

  test "sales history rows require pos transaction view permission" do
    presenter = Items::ItemOperationsTabPresenter.new(
      item: @item,
      store: @store,
      user: @user
    )

    assert_not presenter.sales_visible?
    assert_empty presenter.sales_history_rows

    grant_permission!(@user, "pos.transactions.view", store: @store)

    assert presenter.sales_visible?
    assert_kind_of Array, presenter.sales_history_rows
  end
end
