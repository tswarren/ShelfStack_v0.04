# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/phase85_permissions"

class SetupHomeUxContractTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase85Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "setup_home_ux", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.users.view")
    grant_permission!(@admin, "setup.vendors.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "setup_home_ux", password: "Password123!" }
  end

  test "setup home uses page header card grid and clickable cards" do
    get setup_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Setup"
    assert_select ".ss-page-description", text: /Configure stores, users, classification/
    assert_select ".ss-setup-home"
    assert_select ".ss-setup-section h2", text: "Foundation"
    assert_select "a.ss-card.ss-card--clickable .ss-card__body", text: "Users"
    assert_select "a.ss-card.ss-card--clickable .ss-card__body", text: "Vendors"
    assert_select "a[href='#{setup_users_path}'].ss-card--clickable"
  end

  test "setup home hides links without view permission" do
    get setup_root_path

    assert_response :success
    assert_select "a[href='#{setup_roles_path}']", count: 0
    assert_select "a[href='#{setup_departments_path}']", count: 0
    assert_select "a[href='#{setup_users_path}']", count: 1
  end

  test "setup access alone shows external data sources without other setup links" do
    limited = create_user!(username: "setup_home_limited", password: "Password123!")
    grant_permission!(limited, "setup.access")
    delete logout_path
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "setup_home_limited", password: "Password123!" }

    get setup_root_path

    assert_response :success
    assert_select "a[href='#{setup_external_data_sources_path}'].ss-card--clickable", count: 1
    assert_select "a[href='#{setup_users_path}']", count: 0
    assert_select ".ss-empty-state", count: 0
  end
end
