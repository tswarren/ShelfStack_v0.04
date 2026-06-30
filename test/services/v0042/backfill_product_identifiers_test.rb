# frozen_string_literal: true

require "test_helper"

class V0042BackfillProductIdentifiersTest < ActiveSupport::TestCase
  test "backfills gtin from product sku when no identifiers" do
    product = create_product!(sku: "9780306406157", skip_product_identifier: true)

    ProductIdentifier.delete_all

    result = V0042::BackfillProductIdentifiers.run!
    identifier = product.product_identifiers.active_records.find_by(validation_family: "gtin")

    assert result.backfilled_from_sku.positive?
    assert_equal "9780306406157", identifier.normalized_identifier
  end

  test "preserves legacy local as freeform legacy_local" do
    product = create_product!(sku: "L000000099", skip_product_identifier: true)

    ProductIdentifier.delete_all

    V0042::BackfillProductIdentifiers.run!
    identifier = product.product_identifiers.active_records.first

    assert_equal "freeform", identifier.validation_family
    assert_equal "legacy_local", identifier.freeform_scope
    assert_equal "L000000099", identifier.normalized_identifier
  end

  test "flags needs_review on gtin conflict" do
    first = create_product!(sku: "P-FIRST-CONFLICT", skip_product_identifier: true)
    second = create_product!(sku: "9780306406157", skip_product_identifier: true)

    ProductIdentifier.delete_all
    ProductIdentifier.create!(
      product: first,
      validation_family: "gtin",
      identifier_value: "9780306406157",
      normalized_identifier: "9780306406157",
      primary_identifier: true,
      active: true
    )

    result = V0042::BackfillProductIdentifiers.run!

    assert_includes result.needs_review_product_ids, second.id
    assert second.reload.needs_review?
    assert_nil second.product_identifiers.find_by(normalized_identifier: "9780306406157")
  end
end
