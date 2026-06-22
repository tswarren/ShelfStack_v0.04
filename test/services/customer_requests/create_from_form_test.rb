# frozen_string_literal: true

require "test_helper"

class CustomerRequestsCreateFromFormTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @customer = create_customer!
  end

  test "creates request from controller-style params" do
    request = CustomerRequests::CreateFromForm.call!(
      store: @store,
      created_by_user: @user,
      params: ActionController::Parameters.new(
        customer_request: {
          customer_id: @customer.id,
          source: "in_store",
          customer_request_lines_attributes: {
            "0" => {
              request_type: "research",
              requested_quantity: 1,
              provisional_title: "Mystery title"
            }
          }
        }
      )
    )

    assert request.persisted?
    assert_equal @customer.id, request.customer_id
    assert_equal "research", request.customer_request_lines.first.request_type
  end
end
