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
end
