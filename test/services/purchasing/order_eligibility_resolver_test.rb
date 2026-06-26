# frozen_string_literal: true

require "test_helper"

class Purchasing::OrderEligibilityResolverTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @variant.product.update!(list_price_cents: 2000)
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      supplier_discount_bps: 4000,
      active: true
    )
  end

  test "allows orderable new physical variant for purchase order" do
    result = Purchasing::OrderEligibilityResolver.call(
      product_variant: @variant,
      vendor: @vendor,
      context: :purchase_order
    )

    assert result.eligible
    assert_not result.submit_blocked?
  end

  test "blocks used variant for purchase order but allows tbo" do
    used = ProductCondition.find_by!(condition_key: "used_good")
    @variant.update!(condition: used, orderable: false)

    po_result = Purchasing::OrderEligibilityResolver.call(product_variant: @variant, context: :purchase_order)
    tbo_result = Purchasing::OrderEligibilityResolver.call(product_variant: @variant, context: :tbo)

    assert po_result.blocking?
    assert_includes po_result.blocking_reasons.map(&:code), :used_variant
    assert tbo_result.eligible
  end

  test "discontinued catalog item warns on draft and blocks submit" do
    format = Format.first || Format.create!(format_key: "book", name: "Book", active: true)
    catalog_item = CatalogItem.create!(
      title: "Discontinued Book",
      format: format,
      catalog_item_type: "book",
      publication_status: "discontinued",
      active: true
    )
    @variant.product.update!(catalog_item: catalog_item)

    draft = Purchasing::OrderEligibilityResolver.call(
      product_variant: @variant.reload,
      vendor: @vendor,
      context: :purchase_order
    )
    submit = Purchasing::OrderEligibilityResolver.call(
      product_variant: @variant,
      vendor: @vendor,
      context: :purchase_order_submit
    )

    assert draft.eligible
    assert_includes draft.warnings.map(&:code), :discontinued_catalog_item
    assert submit.submit_blocked?
  end

  test "blocks financial product type" do
    @variant.product.update!(product_type: "financial")

    result = Purchasing::OrderEligibilityResolver.call(product_variant: @variant, context: :purchase_order)

    assert result.blocking?
    assert_includes result.blocking_reasons.map(&:code), :gift_card_or_non_merchandise
  end
end
