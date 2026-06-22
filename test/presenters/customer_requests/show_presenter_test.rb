# frozen_string_literal: true

require "test_helper"

class CustomerRequestsShowPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
    @line.update!(status: "awaiting_customer_response")
  end

  test "contact panel is prominent when a line awaits customer response" do
    presenter = CustomerRequests::ShowPresenter.new(
      customer_request: @request.reload,
      store: @store,
      contact_events: [],
      audit_events: []
    )

    assert presenter.contact_panel_prominent?
    assert_equal 1, presenter.contact_relevant_line_cards.size
    assert_equal 1, presenter.line_cards.size
  end

  test "ready metric counts lines with active reservations even when partially filled" do
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    customer = create_customer!
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "hold", requested_quantity: 2 } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: variant, actor: @user)
    line.update!(status: "partially_filled")
    InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: customer,
      customer_request_line: line
    )

    presenter = CustomerRequests::ShowPresenter.new(
      customer_request: request.reload,
      store: @store,
      contact_events: [],
      audit_events: []
    )

    ready_metric = presenter.metrics.find { |metric| metric[:label] == "Ready" }
    assert_equal 1, ready_metric[:value]
  end
end
