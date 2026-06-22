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

  test "ready_for_pickup queue filters by header status" do
    ready_request = create_customer_request!(store: @store, created_by_user: @user)
    ready_request.update!(status: "ready_for_pickup")

    other_request = create_customer_request!(store: @store, created_by_user: @user)

    ids = scoped_ids("ready_for_pickup")

    assert_includes ids, ready_request.id
    assert_not_includes ids, other_request.id
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
