# frozen_string_literal: true

require "test_helper"

class CustomersProfileIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_all_phase7a_permissions!(@user, store: @store)
    grant_permission!(@user, "demand.create", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    login_user!(@user, workstation: @workstation)
    @customer = create_customer!(display_name: "Profile Pat")
  end

  test "customer profile shows action strip when permissions granted" do
    get customers_customer_path(@customer)

    assert_response :success
    assert_includes response.body, "New demand"
    assert_includes response.body, "Record contact"
  end
end
