# frozen_string_literal: true

require "test_helper"

class CustomerRequestsLineShowPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!
    @request = create_customer_request!(store: @store, created_by_user: @user)
    @line = @request.customer_request_lines.first
  end

  test "unmatched line suggests match item next action" do
    card = CustomerRequests::LineShowPresenter.build(line: @line, store: @store)

    assert_equal "Match item", card.next_action.label
    assert_includes card.trail_steps.map(&:label), "Requested"
  end

  test "ready line is contact relevant" do
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @line.update!(status: "ready_for_pickup", request_type: "hold")

    card = CustomerRequests::LineShowPresenter.build(line: @line.reload, store: @store)

    assert card.contact_relevant?
    assert_equal "Ready for pickup", card.next_action.label
  end

  test "availability summary reflects on hand and available" do
    match_request_line!(line: @line, variant: @variant, actor: @user)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 4, line_number: 1 } ]
      ),
      user: @user
    )

    availability = {
      available: Inventory::Availability.available(store: @store, variant: @variant),
      on_hand: Inventory::Availability.on_hand(store: @store, variant: @variant)
    }
    card = CustomerRequests::LineShowPresenter.build(line: @line.reload, store: @store, availability: availability)

    assert_equal 4, card.availability_summary.on_hand
    assert_equal 4, card.availability_summary.available
  end
end
