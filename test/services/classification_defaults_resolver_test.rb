# frozen_string_literal: true

require "test_helper"

class ClassificationDefaultsResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @tax_category = create_tax_category!(name: "Books Tax", short_name: "Books Tax")
    @department = create_department!(gl_account_code: "1000")
    @sub_department = create_sub_department!(
      sub_department_key: "trade_books",
      name: "Trade Books Resolver",
      short_name: "Trade Resolver",
      department: @department,
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
      sub_department: @sub_department,
      default_pricing_model: "net_cost_markup",
      default_margin_target_bps: 1000
    )
    @product = create_product!
    @variant = create_product_variant!(product: @product, sub_department: @sub_department)
  end

  test "uses variant override first" do
    @variant.update!(pricing_model_override: "pass_through")

    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "variant_override", result.source
    assert_equal "pass_through", result.pricing_model
  end

  test "uses subdepartment defaults" do
    result = ClassificationDefaultsResolver.for(variant: @variant)

    assert_equal "sub_department", result.source
    assert_equal "trade_discount", result.pricing_model
    assert_equal 4000, result.margin_target_bps
    assert_equal "1000", result.sales_account_code
  end

  test "returns none source when subdepartment association unavailable" do
    variant = @variant
    def variant.sub_department
      nil
    end

    result = ClassificationDefaultsResolver.for(variant: variant)

    assert_equal "none", result.source
    assert_includes result.warnings, "No subdepartment assigned; defaults unavailable."
  end
end
