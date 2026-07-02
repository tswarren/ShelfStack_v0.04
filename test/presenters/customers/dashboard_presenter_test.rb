# frozen_string_literal: true

require "test_helper"

class CustomersDashboardPresenterTest < ActiveSupport::TestCase
  include Phase4TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 3)
    @demand_line = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      quantity: 1,
      customer: create_customer!
    ).demand_line
    @allocation = @demand_line.demand_allocations.active_allocations.on_hand_kind.first
  end

  test "ready_for_pickup card includes demand preview" do
    presenter = Customers::DashboardPresenter.new(store: @store)
    card = presenter.queue_cards.find { |queue_card| queue_card.key == "ready_for_pickup" }

    assert card.count.positive?
    row = card.preview_rows.find { |preview_row| preview_row.demand_number == @demand_line.demand_number }

    assert_not_nil row
    assert_equal "POS pickup", row.next_action_label
  end

  test "expiring holds urgency label uses active allocation expiry" do
    @allocation.update!(expires_at: 2.days.from_now)

    presenter = Customers::DashboardPresenter.new(store: @store)
    card = presenter.queue_cards.find { |queue_card| queue_card.key == "expiring_holds" }
    row = card.preview_rows.find { |preview_row| preview_row.demand_number == @demand_line.demand_number }

    assert_not_nil row
    assert_includes row.urgency_label, I18n.l(@allocation.expires_at.to_date)
  end
end
