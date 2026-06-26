# frozen_string_literal: true

require "test_helper"

class Reports::CustomerRequestsControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "repcustreq#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_permission!(@user, "customer_requests.access", store: @store)
  end

  test "renders queue filter without date range fields" do
    get reports_customer_requests_path

    assert_response :success
    assert_select "select#queue"
    assert_select "input[name=start_date]", count: 0
    assert_select "input[name=end_date]", count: 0
  end

  test "renders status badges with existing css classes" do
    get reports_customer_requests_path

    assert_response :success
    assert_select ".ss-status-badge.status-draft", minimum: 0
    assert_no_match(/ss-status-badge--/, response.body)
  end
end
