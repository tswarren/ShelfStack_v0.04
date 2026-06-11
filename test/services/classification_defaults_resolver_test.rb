# frozen_string_literal: true

require "test_helper"

class ClassificationDefaultsResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @tax_category = create_tax_category!(name: "Books Tax", short_name: "Books Tax")
    @department = create_department!(gl_account_code: "1000")
    @merchandise_class = create_merchandise_class!(
      merchandise_class_key: "trade_books",
      name: "Trade Books Resolver",
      short_name: "Trade Resolver",
      default_pricing_model: "trade_discount",
      default_margin_target_bps: 4000,
      default_supplier_discount_bps: 4600,
      default_tax_category: @tax_category,
      default_sales_account_code: "4100",
      vendor_returnable_default: true,
      buyback_allowed: true
    )
    @category = create_category!(
      department: @department,
      default_tax_category: @tax_category,
      merchandise_class: @merchandise_class,
      default_pricing_model: "net_cost_markup",
      default_margin_target_bps: 1000
    )
    @product = create_product!
    @variant = create_product_variant!(product: @product, category: @category)
  end

  test "uses variant override first" do
    @variant.update!(pricing_model_override: "pass_through")

    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "variant_override", result.source
    assert_equal "pass_through", result.pricing_model
  end

  test "uses accounting mapping when present" do
    new_condition = ProductCondition.find_by!(condition_key: "new")
    AccountingMapping.create!(
      merchandise_class: @merchandise_class,
      condition: new_condition,
      sales_account_code: "4999",
      reporting_bucket: "Mapped Sales",
      active: true
    )

    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "accounting_mapping", result.source
    assert_equal "4999", result.sales_account_code
    assert_equal "Mapped Sales", result.reporting_bucket
  end

  test "uses merchandise class defaults when no mapping matches" do
    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "merchandise_class", result.source
    assert_equal "trade_discount", result.pricing_model
    assert_equal 4000, result.margin_target_bps
    assert_equal "4100", result.sales_account_code
  end

  test "falls back to legacy category when merchandise class missing" do
    @category.update!(merchandise_class: nil)

    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "legacy_category", result.source
    assert_equal "net_cost_markup", result.pricing_model
    assert_includes result.warnings, "Merchandise class missing; using legacy category defaults."
  end
end
