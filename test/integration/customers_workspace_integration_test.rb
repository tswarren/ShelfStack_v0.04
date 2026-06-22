# frozen_string_literal: true

require "test_helper"

class CustomersWorkspaceIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "creates customer and customer request" do
    post customers_customers_path, params: {
      customer: { display_name: "Jane Reader", email: "jane@example.com" }
    }
    assert_redirected_to customers_customer_path(Customer.last)

    post customers_customer_requests_path, params: {
      customer_request: {
        customer_id: Customer.last.id,
        source: "in_store",
        customer_request_lines_attributes: {
          "0" => {
            request_type: "research",
            requested_quantity: 1,
            provisional_title: "Rare Book"
          }
        }
      }
    }
    assert_redirected_to customers_customer_request_path(CustomerRequest.last)
    assert CustomerRequest.last.request_number.present?
  end

  test "denies access without permission" do
    UserRoleAssignment.where(user: @user).delete_all
    get customers_customers_path
    assert_redirected_to customers_locked_out_path
  end

  test "customers root shows dashboard for authorized users" do
    get customers_root_path

    assert_response :success
    assert_includes response.body, "Customer Demand"
  end
end
