# frozen_string_literal: true

require "test_helper"

class SetupCategoryNodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "catnodeadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.category_schemes.view setup.category_schemes.create setup.category_schemes.update
      setup.category_schemes.inactivate setup.category_schemes.reactivate setup.category_schemes.delete
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "catnodeadmin", password: "Password123!" }

    @scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |record|
      record.name = "Store Categories"
      record.purpose = CategoryNode::STORE_CATEGORIES_SCHEME_KEY
      record.active = true
    end
    @sub_department = create_sub_department!(name: "General Books", short_name: "GenBooks")
    @display_location = create_display_location!(name: "Fiction Wall", short_name: "FictionWall")
  end

  test "index lists store category nodes as a tree with default columns" do
    parent = @scheme.category_nodes.create!(
      node_key: "parent_a",
      name: "Parent A",
      sort_order: 0,
      active: true,
      default_sub_department: @sub_department,
      default_display_location: @display_location
    )
    child = @scheme.category_nodes.create!(
      node_key: "child_a1",
      name: "Child A1",
      parent: parent,
      sort_order: 5,
      active: true
    )
    @scheme.category_nodes.create!(
      node_key: "parent_b",
      name: "Parent B",
      sort_order: 10,
      active: true
    )

    get setup_category_scheme_category_nodes_path(@scheme)

    assert_response :success
    assert_includes response.body, "ss-table--tree"
    assert_includes response.body, "Default subdepartment"
    assert_includes response.body, "Default display location"
    assert_includes response.body, @sub_department.name
    assert_includes response.body, @display_location.name
    assert response.body.index("Parent A") < response.body.index("Child A1")
    assert response.body.index("Child A1") < response.body.index("Parent B")
  end
end
