# frozen_string_literal: true

require "test_helper"

class FormHelperTest < ActionView::TestCase
  include FormHelper

  test "ss_field_css returns error class when field has errors" do
    department = Department.new
    department.errors.add(:name, "can't be blank")

    assert_equal "ss-field ss-field--error", ss_field_css(department, :name)
    assert_equal "ss-field", ss_field_css(department, :short_name)
  end

  test "ss_field_error renders paragraph for field errors" do
    department = Department.new
    department.errors.add(:name, "can't be blank")

    html = ss_field_error(department, :name)
    assert_includes html, "ss-field-error"
    assert_includes html, "blank"
    assert_nil ss_field_error(department, :short_name)
  end

  test "ss_required_label includes required marker" do
    html = ss_required_label("Name")
    assert_includes html, "Name"
    assert_includes html, "ss-required"
  end
end
