# frozen_string_literal: true

require "test_helper"

class Phase3AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase3Permissions.seed!
    @store_one = create_store!(store_number: "001", name: "Store One")
    @store_two = create_store!(store_number: "002", name: "Store Two")
    @workstation = create_workstation!(store: @store_one)
    @global_admin = create_user!(username: "phase3admin", password: "Password123!")
    grant_all_phase3_permissions!(@global_admin)
    grant_permission!(@global_admin, "setup.access")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "phase3admin", password: "Password123!" }
  end

  test "global admin can access items workspace and setup catalog resources" do
    get items_root_path
    assert_response :success

    get items_catalog_items_path
    assert_redirected_to items_root_path

    get items_products_path
    assert_response :success

    get setup_formats_path
    assert_response :success

    get setup_product_conditions_path
    assert_response :success

    get setup_vendors_path
    assert_response :success
  end

  test "store scoped user can view store display locations only for assigned store" do
    delete logout_path
    store_user = create_user!(username: "storedisplay", password: "Password123!")
    grant_permission!(store_user, "setup.access")
    grant_permission!(store_user, "setup.store_display_locations.view", store: @store_one)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "storedisplay", password: "Password123!" }

    location = create_display_location!(short_name: "Scoped Loc")
    record_one = StoreDisplayLocation.create!(store: @store_one, display_location: location, active: true)
    record_two = StoreDisplayLocation.create!(store: @store_two, display_location: location, active: true)

    get setup_store_display_location_path(record_one)
    assert_response :success

    get setup_store_display_location_path(record_two)
    assert_redirected_to setup_root_path
  end

  test "user without items access cannot open items workspace" do
    delete logout_path
    user = create_user!(username: "noitems", password: "Password123!")
    grant_permission!(user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "noitems", password: "Password123!" }

    get items_root_path
    assert_redirected_to items_locked_out_path
  end

  test "user with items access can browse items index without catalog view permission" do
    delete logout_path
    user = create_user!(username: "itemsaccess", password: "Password123!")
    grant_permission!(user, "items.access")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "itemsaccess", password: "Password123!" }

    get items_root_path
    assert_response :success
  end

  test "user without format permission cannot access formats" do
    delete logout_path
    user = create_user!(username: "noformat", password: "Password123!")
    grant_permission!(user, "setup.access")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "noformat", password: "Password123!" }

    get setup_formats_path
    assert_redirected_to root_path
  end

  test "legacy catalog path redirects to items" do
    get "/catalog/catalog_items"
    assert_redirected_to "/items/catalog_items"
  end
end
