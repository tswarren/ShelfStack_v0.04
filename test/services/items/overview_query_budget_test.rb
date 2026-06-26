# frozen_string_literal: true

require "test_helper"

class Items::OverviewQueryBudgetTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    create_product_variant!(product: @product)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
  end

  test "overview presenter batch loads without per-variant warning builder calls in view layer" do
    queries = count_queries do
      overview = Items::ItemOverviewPresenter.for(item: @item, store: @store, user: @user)
      overview.warnings
      overview.matrix_rows
      overview.summary_cards
    end

    assert queries < 100, "expected bounded query count, got #{queries}"
  end

  private

  def count_queries
    count = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA CACHE])
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    count
  end
end
