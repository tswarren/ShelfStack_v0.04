# frozen_string_literal: true

require "test_helper"

class CustomerRequestsRecordContactTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @customer = create_customer!
    @request = create_customer_request!(store: @store, created_by_user: @user, customer: @customer)
  end

  test "records contact for customer request" do
    event = CustomerRequests::RecordContact.call!(
      actor: @user,
      customer_request: @request,
      contact_method: "phone",
      summary: "Left voicemail"
    )

    assert_equal @customer.id, event.customer_id
    assert_equal @request.id, event.customer_request_id
    assert @request.reload.last_contacted_at.present?
  end

  test "records contact for customer only" do
    event = CustomerRequests::RecordContact.call!(
      actor: @user,
      customer: @customer,
      contact_method: "email",
      summary: "Sent follow-up email"
    )

    assert_equal @customer.id, event.customer_id
    assert_nil event.customer_request_id
  end
end
