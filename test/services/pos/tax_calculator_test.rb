# frozen_string_literal: true

require "test_helper"

class Pos::TaxCalculatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    @business_date = Date.current
  end

  test "variant snapshot uses business date rate and rounds tax cents" do
    line_tax = Pos::TaxCalculator.snapshot_for_variant!(
      variant: @variant,
      store: @store,
      business_date: @business_date,
      taxable_cents: 1000
    )

    assert_equal @tax_category, line_tax.tax_category
    assert_equal @rate, line_tax.store_tax_rate
    assert_equal 600, line_tax.tax_rate_bps
    assert_equal 60, line_tax.tax_cents
  end

  test "subdepartment snapshot resolves default tax category for open ring lines" do
    line_tax = Pos::TaxCalculator.snapshot_for_subdepartment!(
      sub_department: @variant.sub_department,
      store: @store,
      business_date: @business_date,
      taxable_cents: 500
    )

    assert_equal @tax_category, line_tax.tax_category
    assert_equal 30, line_tax.tax_cents
  end

  test "raises when subdepartment has no default tax category" do
    sub_department = SubDepartment.new

    assert_raises(Pos::TaxCalculator::MissingTaxError) do
      Pos::TaxCalculator.snapshot_for_subdepartment!(
        sub_department: sub_department,
        store: @store,
        business_date: @business_date,
        taxable_cents: 500
      )
    end
  end

  test "raises when variant has no resolvable tax category" do
    @variant.sub_department.define_singleton_method(:default_tax_category) { nil }

    assert_raises(Pos::TaxCalculator::MissingTaxError) do
      Pos::TaxCalculator.snapshot_for_variant!(
        variant: @variant,
        store: @store,
        business_date: @business_date,
        taxable_cents: 1000
      )
    end
  end

  test "raises when no active store tax rate applies on business date" do
    StoreTaxCategoryRate.where(store: @store, tax_category: @tax_category).delete_all

    assert_raises(TaxRateLookup::MissingRateError) do
      Pos::TaxCalculator.snapshot_for_variant!(
        variant: @variant,
        store: @store,
        business_date: @business_date,
        taxable_cents: 1000
      )
    end
  end
end
