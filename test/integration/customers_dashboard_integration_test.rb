# frozen_string_literal: true

require "test_helper"

class CustomersDashboardIntegrationTest < ActionDispatch::IntegrationTest
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @ready_request = create_customer_request!(store: @store, created_by_user: @user)
    @ready_request.update!(status: "ready_for_pickup")
  end

  test "customers root renders dashboard instead of redirecting" do
    get customers_root_path

    assert_response :success
    assert_includes response.body, "Customer Demand"
    assert_includes response.body, "Ready for pickup"
    assert_includes response.body, @ready_request.request_number
  end

  test "dashboard queue card links to filtered request index" do
    get customers_root_path

    assert_includes response.body, customers_customer_requests_path(queue: "ready_for_pickup")
  end
end
