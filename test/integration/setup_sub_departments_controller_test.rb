# frozen_string_literal: true

require "test_helper"

class SetupSubDepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "mcadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_all_phase3b_permissions!(@admin)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "mcadmin", password: "Password123!" }
    @tax_category = create_tax_category!
  end

  test "create subdepartment" do
    department = create_department!
    post setup_sub_departments_path, params: {
      sub_department: {
        sub_department_key: "sidelines",
        name: "Sidelines Test",
        short_name: "Sidelines T",
        department_id: department.id,
        default_tax_category_id: @tax_category.id,
        active: true
      }
    }

    sub_department = SubDepartment.find_by!(sub_department_key: "sidelines")
    assert_equal "Sidelines Test", sub_department.name
    assert AuditEvent.exists?(event_name: "sub_department.created", auditable: sub_department)
  end

  test "index lists departments and subdepartments as a tree with default columns" do
    department = create_department!(department_number: "015", name: "Tree Dept", short_name: "TreeDept")
    sub_department = create_sub_department!(
      department: department,
      name: "Tree Sub",
      short_name: "TreeSub",
      default_tax_category: @tax_category,
      default_margin_target_bps: 4000
    )

    get setup_sub_departments_path

    assert_response :success
    assert_includes response.body, "ss-table--tree"
    assert_includes response.body, "Default margin target"
    assert_includes response.body, @tax_category.name
    assert_includes response.body, "40.00%"
    assert response.body.index("015 — Tree Dept") < response.body.index("Tree Sub")
  end
end
