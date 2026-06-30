# frozen_string_literal: true

require "test_helper"

class ProductIdentifierTest < ActiveSupport::TestCase
  test "only one active primary identifier per product" do
    product = create_product!
    primary = ProductIdentifier.create!(
      product: product,
      validation_family: "gtin",
      identifier_value: "9780143127741",
      normalized_identifier: "9780143127741",
      primary_identifier: true,
      active: true
    )

    duplicate = product.product_identifiers.build(
      validation_family: "freeform",
      identifier_value: "ABC123",
      normalized_identifier: "ABC123",
      freeform_scope: "publisher_number",
      primary_identifier: true,
      active: true
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end

    assert primary.reload.primary_identifier?
  end

  test "freeform requires freeform_scope" do
    product = create_product!
    identifier = product.product_identifiers.build(
      validation_family: "freeform",
      identifier_value: "L000000001",
      normalized_identifier: "L000000001",
      active: true
    )

    assert_not identifier.valid?
    assert_includes identifier.errors[:freeform_scope], "is required for freeform identifiers"
  end

  test "global gtin uniqueness enforced at database level" do
    first_product = create_product!(sku: "P-FIRST-001")
    second_product = create_product!(sku: "P-SECOND-001")

    ProductIdentifier.create!(
      product: first_product,
      validation_family: "gtin",
      identifier_value: "9780143127741",
      normalized_identifier: "9780143127741",
      active: true
    )

    duplicate = ProductIdentifier.new(
      product: second_product,
      validation_family: "gtin",
      identifier_value: "9780143127741",
      normalized_identifier: "9780143127741",
      active: true
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  test "freeform uniqueness is scoped per product" do
    first_product = create_product!(sku: "P-FREEFORM-1")
    second_product = create_product!(sku: "P-FREEFORM-2")

    ProductIdentifier.create!(
      product: first_product,
      validation_family: "freeform",
      identifier_value: "VENDOR-1",
      normalized_identifier: "VENDOR-1",
      freeform_scope: "vendor_catalog",
      active: true
    )

    assert_nothing_raised do
      ProductIdentifier.create!(
        product: second_product,
        validation_family: "freeform",
        identifier_value: "VENDOR-1",
        normalized_identifier: "VENDOR-1",
        freeform_scope: "vendor_catalog",
        active: true
      )
    end
  end
end
