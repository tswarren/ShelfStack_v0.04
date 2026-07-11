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

  test "ss_field_dom_id uses dom_id suffix convention" do
    department = Department.new
    assert_equal dom_id(department, "name_help"), ss_field_dom_id(department, :name, "help")
  end

  test "ss_field_describedby_ids composes help warning and error ids" do
    department = Department.new
    department.errors.add(:name, "can't be blank")

    ids = ss_field_describedby_ids(department, :name, help: "Hint", warning: "Careful")
    assert_includes ids, ss_field_dom_id(department, :name, "help")
    assert_includes ids, ss_field_dom_id(department, :name, "warning")
    assert_includes ids, ss_field_dom_id(department, :name, "error")
  end

  test "ss_field_aria marks invalid fields and describedby" do
    department = Department.new
    department.errors.add(:name, "can't be blank")

    aria = ss_field_aria(department, :name, help: "Hint")
    assert_equal true, aria[:invalid]
    assert_includes aria[:describedby], ss_field_dom_id(department, :name, "help")
    assert_includes aria[:describedby], ss_field_dom_id(department, :name, "error")
  end

  test "ss_field_warning renders warning paragraph with id" do
    department = Department.new
    html = ss_field_warning(department, :name, message: "Below target margin.")

    assert_includes html, "ss-field-warning"
    assert_includes html, ss_field_dom_id(department, :name, "warning")
  end

  test "ss_field_error includes error id" do
    department = Department.new
    department.errors.add(:name, "can't be blank")

    html = ss_field_error(department, :name)
    assert_includes html, "ss-field-error"
    assert_includes html, ss_field_dom_id(department, :name, "error")
  end

  test "sub_department_options_grouped_by_department groups by parent department name" do
    books = create_department!(name: "Books Dept", short_name: "BKS", department_number: "101")
    gifts = create_department!(name: "Gifts Dept", short_name: "GFT", department_number: "102")
    fiction = create_sub_department!(department: books, name: "Fiction", short_name: "FIC", sub_department_key: "fiction_grp")
    cards = create_sub_department!(department: gifts, name: "Cards", short_name: "CRD", sub_department_key: "cards_grp")

    groups = sub_department_options_grouped_by_department(SubDepartment.where(id: [ fiction.id, cards.id ]))

    assert_equal [ "Books Dept", "Gifts Dept" ], groups.map(&:first)
    assert_includes groups.assoc("Books Dept").last, [ "Fiction", fiction.id ]
    assert_includes groups.assoc("Gifts Dept").last, [ "Cards", cards.id ]
  end
end
