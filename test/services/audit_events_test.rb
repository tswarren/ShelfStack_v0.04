# frozen_string_literal: true

require "test_helper"

class AuditEventsTest < ActiveSupport::TestCase
  test "build_details for created records attribute snapshot" do
    department = Department.create!(
      department_number: "001",
      name: "Books",
      short_name: "Books",
      active: true
    )

    details = AuditEvents.build_details(
      auditable: department,
      event_name: "department.created"
    )

    assert_equal "001", details["attributes"]["department_number"]
    assert_equal "Books", details["attributes"]["name"]
    assert_not details["attributes"].key?("id")
  end

  test "build_details for updated records captures saved changes" do
    department = Department.create!(
      department_number: "002",
      name: "Periodicals",
      short_name: "Periodicals",
      active: true
    )
    department.update!(name: "Magazines")

    details = AuditEvents.build_details(
      auditable: department,
      event_name: "department.updated"
    )

    assert_equal "Periodicals", details["changes"]["name"]["from"]
    assert_equal "Magazines", details["changes"]["name"]["to"]
  end

  test "build_details merges explicit extra details" do
    role = create_role!(role_key: "test_role", name: "Test Role")

    details = AuditEvents.build_details(
      auditable: role,
      event_name: "role.permission_added",
      extra: { permission_key: "setup.access" }
    )

    assert_equal "setup.access", details["permission_key"]
    assert_not details.key?("attributes")
  end

  test "build_details for inactivated records includes active flag" do
    tax_category = TaxCategory.create!(name: "Books", short_name: "Books", sort_order: 10, active: false)

    details = AuditEvents.build_details(
      auditable: tax_category,
      event_name: "tax_category.inactivated"
    )

    assert_equal false, details["active"]
  end
end
