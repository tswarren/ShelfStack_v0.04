# frozen_string_literal: true

require "test_helper"

class Pos::SellabilityValidatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000
      } ]
    )
  end

  test "raises when variant has no subdepartment" do
    line = @transaction.pos_transaction_lines.first
    variant = line.product_variant
    variant.define_singleton_method(:sub_department) { nil }
    line.define_singleton_method(:product_variant) { variant }
    @transaction.define_singleton_method(:pos_transaction_lines) { [ line ] }

    error = assert_raises(Pos::SellabilityValidator::Error) do
      Pos::SellabilityValidator.validate!(@transaction)
    end

    assert_match(/no subdepartment/i, error.message)
  end

  test "raises when tax rate cannot be resolved" do
    StoreTaxCategoryRate.where(store: @store, tax_category: @variant.sub_department.default_tax_category).delete_all

    assert_raises(TaxRateLookup::MissingRateError) do
      Pos::SellabilityValidator.validate!(@transaction.reload)
    end
  end

  test "raises for inactive variant without confirmation" do
    @variant.update!(active: false)

    error = assert_raises(Pos::SellabilityValidator::Error) do
      Pos::SellabilityValidator.validate!(@transaction.reload)
    end

    assert_match(/inactive/i, error.message)
  end

  test "allows inactive variant when confirmed" do
    @variant.update!(active: false)

    assert_nothing_raised do
      Pos::SellabilityValidator.validate!(@transaction.reload, confirmed_inactive: true)
    end
  end

  test "warnings_for returns inactive sell warning without raising" do
    @variant.update!(active: false)

    warnings = Pos::SellabilityValidator.warnings_for(@transaction.reload)

    assert_equal 1, warnings.size
    assert_equal :inactive_sell, warnings.first.code
  end
end
