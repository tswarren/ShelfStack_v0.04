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

  test "backfills house from 201 product sku" do
    house_sku = InternalEanAllocator.allocate!(segment: "201", purpose: "product_house")
    product = create_product!(sku: house_sku, skip_product_identifier: true)

    ProductIdentifier.delete_all

    V0042::BackfillProductIdentifiers.run!
    identifier = product.product_identifiers.active_records.find_by(validation_family: "house")

    assert_equal house_sku, identifier.normalized_identifier
    assert identifier.primary_identifier?
    assert identifier.valid_check_digit?
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

  test "legacy isbn10 row creates gtin primary and isbn alternate" do
    product = create_product!(sku: "P-LEGACY-ISBN10", skip_product_identifier: true)
    legacy = legacy_row(
      identifier_type: "isbn10",
      identifier_value: "0123456789",
      normalized_identifier: "0123456789",
      primary_identifier: true
    )

    V0042::BackfillProductIdentifiers.new.send(:copy_legacy_row_to_product!, product, legacy)

    isbn = product.product_identifiers.find_by(validation_family: "isbn")
    gtin = product.product_identifiers.find_by(validation_family: "gtin", normalized_identifier: "9780123456786")

    assert_equal "0123456789", isbn.normalized_identifier
    assert gtin.primary_identifier?
  end

  test "legacy isbn13 row creates gtin and isbn10 alternate for 978 prefix" do
    product = create_product!(sku: "P-LEGACY-ISBN13", skip_product_identifier: true)
    legacy = legacy_row(
      identifier_type: "isbn13",
      identifier_value: "9780306406157",
      normalized_identifier: "9780306406157",
      primary_identifier: true
    )

    V0042::BackfillProductIdentifiers.new.send(:copy_legacy_row_to_product!, product, legacy)

    gtin = product.product_identifiers.find_by(validation_family: "gtin", normalized_identifier: "9780306406157")
    isbn = product.product_identifiers.find_by(validation_family: "isbn")

    assert gtin.primary_identifier?
    assert_equal "0306406152", isbn.normalized_identifier
  end

  test "attempts legacy copy for every linked product and flags global gtin conflicts" do
    catalog_item = create_catalog_item!
    first_product = create_legacy_catalog_linked_product!(catalog_item: catalog_item, skip_product_identifier: true)
    second_product = Product.create!(
      {
        catalog_item: catalog_item,
        name: "Second linked product",
        sku: "PSECOND#{SecureRandom.hex(2)}",
        product_type: "physical",
        variation_type: "standard",
        list_price_cents: 1000,
        active: true
      }.merge(catalog_metadata_attrs_for(catalog_item))
    )
    legacy = legacy_row(
      identifier_type: "isbn13",
      identifier_value: "9780306406157",
      normalized_identifier: "9780306406157",
      primary_identifier: true
    )
    backfill = V0042::BackfillProductIdentifiers.new

    backfill.send(:copy_legacy_row_to_product!, first_product, legacy)
    backfill.send(:copy_legacy_row_to_product!, second_product, legacy)

    assert first_product.product_identifiers.exists?(normalized_identifier: "9780306406157")
    assert second_product.reload.needs_review?
    assert_not second_product.product_identifiers.exists?(normalized_identifier: "9780306406157")
  end

  private

  def legacy_row(identifier_type:, identifier_value:, normalized_identifier:, primary_identifier:)
    {
      "id" => SecureRandom.random_number(10_000),
      "identifier_type" => identifier_type,
      "identifier_value" => identifier_value,
      "normalized_identifier" => normalized_identifier,
      "primary_identifier" => primary_identifier,
      "active" => true,
      "valid_check_digit" => true,
      "validation_message" => nil,
      "source" => "manual"
    }
  end
end
