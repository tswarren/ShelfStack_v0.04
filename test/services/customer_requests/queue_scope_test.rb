# frozen_string_literal: true

require "test_helper"

class CustomerRequestsQueueScopeTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!
  end

  test "needs_research queue includes requests with unmatched open lines" do
    matched_request = create_customer_request!(store: @store, created_by_user: @user)
    matched_request.customer_request_lines.first.update!(
      product_variant: @variant,
      status: "matched"
    )

    unmatched_request = create_customer_request!(store: @store, created_by_user: @user)

    ids = scoped_ids("needs_research")

    assert_includes ids, unmatched_request.id
    assert_not_includes ids, matched_request.id
    assert_equal 1, CustomerRequests::QueueScope.count(store: @store, queue_key: "needs_research")
  end

  test "ready_for_pickup queue includes mixed-line requests with any ready line" do
    mixed_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [
        { request_type: "hold", requested_quantity: 1 },
        { request_type: "special_order", requested_quantity: 1 }
      ]
    )
    line1, line2 = mixed_request.customer_request_lines.order(:line_number).to_a
    match_request_line!(line: line1, variant: @variant, actor: @user)
    match_request_line!(line: line2, variant: @variant, actor: @user)
    line1.update!(status: "ready_for_pickup")
    line2.update!(status: "ordered")
    mixed_request.refresh_status_from_lines!
    assert_equal "partially_filled", mixed_request.status

    other_request = create_customer_request!(store: @store, created_by_user: @user)
    other_request.customer_request_lines.first.update!(
      product_variant: @variant,
      status: "ordered"
    )
    other_request.refresh_status_from_lines!

    ids = scoped_ids("ready_for_pickup")

    assert_includes ids, mixed_request.id
    assert_not_includes ids, other_request.id
  end

  test "ready_for_pickup queue includes requests with ready on-hand reservations" do
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: create_customer!,
      lines: [ { request_type: "hold" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: @variant, actor: @user)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: request.customer,
      customer_request_line: line
    )
    reservation.update!(status: "ready")
    line.update!(status: "matched")
    request.refresh_status_from_lines!

    ids = scoped_ids("ready_for_pickup")

    assert_includes ids, request.id
  end

  test "counts_for returns counts for all queue keys" do
    create_customer_request!(store: @store, created_by_user: @user)

    counts = CustomerRequests::QueueScope.counts_for(store: @store)

    assert_equal CustomerRequests::QueueScope::QUEUE_KEYS.sort, counts.keys.sort
    assert counts.values.all? { |count| count.is_a?(Integer) }
  end

  private

  def scoped_ids(queue_key)
    CustomerRequests::QueueScope.apply(
      CustomerRequest.where(store: @store),
      queue_key,
      store: @store
    ).pluck(:id)
  end
end
