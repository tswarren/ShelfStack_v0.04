# frozen_string_literal: true

require "test_helper"

class SetupDisplayLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "displayadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.display_locations.view setup.display_locations.create setup.display_locations.update
      setup.display_locations.inactivate setup.display_locations.reactivate setup.display_locations.delete
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "displayadmin", password: "Password123!" }
  end

  test "index lists display locations as a tree ordered by top parents then children" do
    parent_a = create_display_location!(name: "Parent A", short_name: "PA", sort_order: 0, parent_id: nil)
    child = create_display_location!(name: "Child A1", short_name: "CA1", sort_order: 5, parent: parent_a)
    parent_b = create_display_location!(name: "Parent B", short_name: "PB", sort_order: 10, parent_id: nil)

    get setup_display_locations_path

    assert_response :success
    assert_includes response.body, "ss-table--tree"
    assert response.body.index("Parent A") < response.body.index("Child A1")
    assert response.body.index("Child A1") < response.body.index("Parent B")
  end
end
