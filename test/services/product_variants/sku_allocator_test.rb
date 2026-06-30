# frozen_string_literal: true

require "test_helper"

module ProductVariants
  class SkuAllocatorTest < ActiveSupport::TestCase
    test "new variant receives generated sku from segment 211" do
      product = create_product!(sku: "P-SKU-ALLOC-1")
      sub_department = create_product_variant!.sub_department
      variant = ProductVariant.new(
        product: product,
        sub_department: sub_department,
        condition: ProductCondition.find_by!(condition_key: "new"),
        name: product.name,
        selling_price_cents: 1000,
        inventory_behavior: "standard_physical",
        active: true
      )
      actor = create_user!(username: "skuactor")

      sku = SkuAllocator.generate!(product_variant: variant, actor: actor)

      assert_match(/\A211[0-9]{9}[0-9]\z/, sku)
      assert_equal sku, variant.reload.sku
      assert AuditEvent.exists?(event_name: "variant_sku.generated", auditable: variant)
    end

    test "does not overwrite existing sku" do
      product = create_product!(sku: "P-SKU-ALLOC-2")
      variant = create_product_variant!(product: product, sku: "LEGACY-SKU-001")

      assert_raises(SkuAllocator::AllocationError) do
        SkuAllocator.generate!(product_variant: variant)
      end
    end
  end
end
