# frozen_string_literal: true

require "test_helper"

class SetupPhase2AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @store_one = create_store!(store_number: "001", name: "Store One")
    @store_two = create_store!(store_number: "002", name: "Store Two")
    @workstation = create_workstation!(store: @store_one)
    @global_admin = create_user!(username: "phase2admin", password: "Password123!")
    grant_all_setup_permissions!(@global_admin)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "phase2admin", password: "Password123!" }
  end

  test "global admin can access phase 2 setup screens" do
    get setup_tax_categories_path
    assert_response :success

    get setup_departments_path
    assert_response :success

    get setup_store_tax_rates_path
    assert_response :success
  end

  test "store scoped user can view store tax rates only for assigned store" do
    delete logout_path
    store_user = create_user!(username: "storetax", password: "Password123!")
    grant_permission!(store_user, "setup.access")
    grant_permission!(store_user, "setup.store_tax_rates.view", store: @store_one)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "storetax", password: "Password123!" }

    rate_one = create_store_tax_rate!(store: @store_one, name: "Store One Rate", tax_identifier: "A")
    rate_two = create_store_tax_rate!(store: @store_two, name: "Store Two Rate", tax_identifier: "B")

    get setup_store_tax_rate_path(rate_one)
    assert_response :success

    get setup_store_tax_rate_path(rate_two)
    assert_redirected_to setup_root_path
  end

  test "user without department permission cannot access departments" do
    delete logout_path
    user = create_user!(username: "notdept", password: "Password123!")
    grant_permission!(user, "setup.access")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "notdept", password: "Password123!" }

    get setup_departments_path
    assert_redirected_to root_path
  end

  private

  def grant_all_setup_permissions!(user)
    Permission.active_records.find_each do |permission|
      grant_permission!(user, permission.permission_key)
    end
  end
end
