# frozen_string_literal: true

require "test_helper"

class SetupDepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "deptadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.departments.view setup.departments.create setup.departments.update
      setup.departments.inactivate setup.departments.reactivate setup.departments.delete
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "deptadmin", password: "Password123!" }
  end

  test "create department normalizes department number" do
    post setup_departments_path, params: {
      department: { department_number: "5", name: "Maps", short_name: "Maps", active: true }
    }

    department = Department.last
    assert_equal "005", department.department_number
    assert AuditEvent.exists?(event_name: "department.created", auditable: department)
    event = AuditEvent.find_by!(event_name: "department.created", auditable: department)
    assert_equal "005", event.event_details.dig("attributes", "department_number")
  end

  test "cannot delete department with subdepartments" do
    department = create_department!(department_number: "010", name: "Maps Dept", short_name: "Maps")
    create_sub_department!(department: department, name: "Road Maps", short_name: "Road")

    assert_no_difference -> { Department.count } do
      delete setup_department_path(department)
    end

    assert_redirected_to setup_department_path(department)
  end
end
