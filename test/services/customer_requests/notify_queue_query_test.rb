# frozen_string_literal: true

require "test_helper"

class CustomerRequestsNotifyQueueQueryTest < ActiveSupport::TestCase
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
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "notify", provisional_title: "Notify title" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
  end

  test "qualifies notify line with available stock and no reservation" do
    assert CustomerRequests::NotifyQueueQuery.qualifies?(@line, store: @store)
    assert_includes CustomerRequests::NotifyQueueQuery.customer_request_ids_for(store: @store), @customer_request.id
  end
end
