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
    category_count = Category.count
    merchandise_class_count = MerchandiseClass.count

    load Rails.root.join("db/seeds.rb")

    assert_equal user_count, User.count
    assert_equal permission_count, Permission.count
    assert_equal store_count, Store.count
    assert_equal tax_category_count, TaxCategory.count
    assert_equal department_count, Department.count
    assert_equal category_count, Category.count
    assert_equal merchandise_class_count, MerchandiseClass.count
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
