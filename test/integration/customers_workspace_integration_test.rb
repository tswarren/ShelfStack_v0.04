# frozen_string_literal: true

require "test_helper"

class CustomersWorkspaceIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "creates customer and demand line" do
    post customers_customers_path, params: {
      customer: { display_name: "Jane Reader", email: "jane@example.com" }
    }
    assert_redirected_to customers_customer_path(Customer.last)

    post demand_demand_lines_path, params: {
      customer_id: Customer.last.id,
      capture_intent: "research",
      provisional_title: "Rare Book",
      quantity: 1
    }
    assert_redirected_to demand_demand_line_path(DemandLine.last)
    assert DemandLine.last.demand_number.present?
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
