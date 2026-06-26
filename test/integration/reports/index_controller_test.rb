# frozen_string_literal: true

require "test_helper"

class Reports::IndexControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "rephub#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
  end

  test "redirects when user has no report permissions" do
    get reports_root_path
    assert_redirected_to root_path
  end

  test "shows hub when user has report permission" do
    grant_permission!(@user, "pos.reports.sales", store: @store)

    get reports_root_path
    assert_response :success
    assert_select "h1", text: "Reports"
    assert_select "a", text: "Sales List"
  end
end
