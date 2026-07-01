# frozen_string_literal: true

require "test_helper"

class Items::PersistInitialProductIdentifierTest < ActiveSupport::TestCase
  setup do
    @product = create_product!(skip_product_identifier: true)
  end

  test "adds legacy identifier when value present" do
    result = Items::PersistInitialProductIdentifier.call(
      product: @product,
      identifier_type: "isbn13",
      identifier_value: "9780306406157"
    )

    assert_not result.skipped
    assert_equal "9780306406157", result.identifier.normalized_identifier
    assert result.identifier.primary_identifier?
    assert_equal "9780306406157", @product.reload.sku
  end

  test "syncs from product sku when identifier value absent" do
    @product.update!(sku: "9780306406157")

    result = Items::PersistInitialProductIdentifier.call(product: @product)

    assert_not result.skipped
    assert_equal "9780306406157", result.identifier.normalized_identifier
  end

  test "skips when product already has identifiers" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780306406157",
      primary: true
    )
    before_count = @product.product_identifiers.active_records.count
    assert before_count.positive?

    result = Items::PersistInitialProductIdentifier.call(
      product: @product,
      identifier_type: "isbn13",
      identifier_value: "9780123456789"
    )

    assert result.skipped
    assert_nil result.identifier
    assert_equal before_count, @product.product_identifiers.active_records.count
  end
end
