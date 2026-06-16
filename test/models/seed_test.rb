# frozen_string_literal: true

require "test_helper"

class SeedTest < ActiveSupport::TestCase
  test "seeds are idempotent" do
    original_stdout = $stdout
    $stdout = StringIO.new

    load Rails.root.join("db/seeds.rb")
    user_count = User.count
    permission_count = Permission.count
    store_count = Store.count
    tax_category_count = TaxCategory.count
    department_count = Department.count
    sub_department_count = SubDepartment.count
    display_location_count = DisplayLocation.count
    store_category_count = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
                                           &.category_nodes&.count.to_i

    load Rails.root.join("db/seeds.rb")

    assert_equal user_count, User.count
    assert_equal permission_count, Permission.count
    assert_equal store_count, Store.count
    assert_equal tax_category_count, TaxCategory.count
    assert_equal department_count, Department.count
    assert_equal sub_department_count, SubDepartment.count
    assert_equal display_location_count, DisplayLocation.count
    assert_equal store_category_count,
                 CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)&.category_nodes&.count.to_i
  ensure
    $stdout = original_stdout
  end

  test "super administrator receives phase 3B setup permissions" do
    original_stdout = $stdout
    $stdout = StringIO.new

    load Rails.root.join("db/seeds.rb")

    super_admin = Role.find_by!(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY)
    permission = Permission.find_by!(permission_key: "setup.sub_departments.view")

    assert super_admin.permissions.exists?(id: permission.id)
  ensure
    $stdout = original_stdout
  end

  test "reference trees seed display locations and store categories from csv" do
    original_stdout = $stdout
    $stdout = StringIO.new

    load Rails.root.join("db/seeds.rb")

    assert_operator DisplayLocation.active_records.count, :>=, 20
    store_scheme = CategoryScheme.find_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
    assert_operator store_scheme.category_nodes.active_records.count, :>=, 140

    fiction = store_scheme.category_nodes.find_by!(node_key: "fiction")
    assert fiction.default_sub_department.present?
    assert fiction.default_display_location.present?
  ensure
    $stdout = original_stdout
  end

  test "seeded tax lookup succeeds for all store and tax category pairs" do
    original_stdout = $stdout
    $stdout = StringIO.new

    load Rails.root.join("db/seeds.rb")

    Store.find_each do |store|
      TaxCategory.active_records.find_each do |tax_category|
        assert_nothing_raised do
          TaxRateLookup.call(store: store, tax_category: tax_category, date: Date.new(2026, 6, 15))
        end
      end
    end
  ensure
    $stdout = original_stdout
  end
end
