# frozen_string_literal: true

require "test_helper"

class CustomersDashboardPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!
    @request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    @line = @request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
  end

  test "expiring holds urgency label ignores released holds" do
    InventoryReservation.create!(
      store: @store,
      customer: @customer,
      customer_request_line: @line,
      product_variant: @variant,
      reservation_type: "on_hand_hold",
      status: "released",
      quantity_reserved: 1,
      reserved_by_user: @user,
      reserved_at: 1.week.ago,
      expires_at: 1.day.from_now,
      release_reason: "staff_release"
    )
    active_hold = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: @customer,
      customer_request_line: @line,
      expires_at: 2.days.from_now
    )
    active_hold.update!(status: "ready")

    presenter = Customers::DashboardPresenter.new(store: @store)
    card = presenter.queue_cards.find { |queue_card| queue_card.key == "expiring_holds" }
    row = card.preview_rows.find { |preview_row| preview_row.request_number == @request.request_number }

    assert_not_nil row, "Expected request in expiring_holds preview"
    assert_includes row.urgency_label, I18n.l(active_hold.expires_at.to_date)
    refute_includes row.urgency_label, I18n.l(1.day.from_now.to_date)
  end
end
