# frozen_string_literal: true

require "test_helper"

class ProductIdentifierServiceTest < ActiveSupport::TestCase
  setup do
    @product = create_product!(sku: "P-ID-TEST-001", name: "Identifier Test Product", skip_product_identifier: true)
    @actor = create_user!(username: "pidactor")
  end

  test "normalizes gtin identifiers to digits only" do
    identifier = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "978-0-123456-78-9",
      primary: true
    )

    assert_equal "gtin", identifier.validation_family
    assert_equal "9780123456789", identifier.normalized_identifier
    assert_equal "9780123456789", @product.reload.sku
  end

  test "validation_preview reports invalid gtin" do
    preview = ProductIdentifierService.validation_preview(
      validation_family: "gtin",
      value: "9780123456780"
    )

    assert_equal "9780123456780", preview[:normalized]
    assert_equal false, preview[:valid]
    assert_match(/invalid/i, preview[:message])
  end

  test "isbn10 creates gtin primary and isbn alternate" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "isbn",
      value: "0123456789",
      primary: true,
      actor: @actor
    )

    isbn = @product.product_identifiers.find_by(validation_family: "isbn")
    gtin = @product.product_identifiers.find_by(validation_family: "gtin", normalized_identifier: "9780123456786")

    assert_equal "0123456789", isbn.normalized_identifier
    assert_not isbn.primary_identifier?
    assert gtin.primary_identifier?
    assert AuditEvent.exists?(event_name: "product_identifier.isbn_alternate_created")
    assert AuditEvent.exists?(event_name: "product_identifier.created")
  end

  test "isbn13 978 creates non-primary isbn10 alternate" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780306406157",
      primary: true,
      actor: @actor
    )

    isbn = @product.product_identifiers.find_by(validation_family: "isbn")
    assert_equal "0306406152", isbn.normalized_identifier
    assert_not isbn.primary_identifier?
    assert AuditEvent.exists?(event_name: "product_identifier.isbn_alternate_created")
  end

  test "isbn13 979 does not create isbn10 alternate" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9791234567890",
      primary: true
    )

    assert_nil @product.product_identifiers.find_by(validation_family: "isbn")
  end

  test "publisher number freeform preserves display and normalizes searchable value" do
    identifier = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "freeform",
      value: "ABC 123-45",
      freeform_scope: "publisher_number",
      primary: true
    )

    assert_equal "ABC 123-45", identifier.identifier_value
    assert_equal "ABC12345", identifier.normalized_identifier
    assert_nil identifier.valid_check_digit
  end

  test "generate house identifier uses segment 201" do
    identifier = ProductIdentifierService.generate_house!(product: @product, actor: @actor)

    assert_equal "house", identifier.validation_family
    assert_match(/\A201[0-9]{9}[0-9]\z/, identifier.normalized_identifier)
    assert identifier.primary_identifier?
    assert AuditEvent.exists?(event_name: "product_identifier.house_generated", auditable: identifier)
  end

  test "legacy local preserved as freeform legacy_local" do
    identifier = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "freeform",
      value: "L000000001",
      primary: true
    )

    assert_equal "legacy_local", identifier.freeform_scope
    assert_equal "L000000001", identifier.normalized_identifier
  end

  test "set primary clears previous primary and syncs products.sku cache" do
    first = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780123456789",
      primary: true,
      actor: @actor
    )
    second = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "freeform",
      value: "SECOND-ID",
      freeform_scope: "import_reference",
      primary: false
    )

    ProductIdentifierService.set_primary!(identifier: second, actor: @actor)

    assert_not first.reload.primary_identifier?
    assert second.reload.primary_identifier?
    assert_equal "SECOND-ID", @product.reload.sku
    assert AuditEvent.exists?(event_name: "product_identifier.primary_changed", auditable: second)
  end

  test "inactivate identifier reassigns primary" do
    primary = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9791234567890",
      primary: true,
      actor: @actor
    )
    secondary = ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "freeform",
      value: "ALT-ID",
      freeform_scope: "import_reference",
      primary: false
    )

    ProductIdentifierService.inactivate_identifier!(identifier: primary, actor: @actor)

    assert_not primary.reload.active?
    assert secondary.reload.primary_identifier?
    assert AuditEvent.exists?(event_name: "product_identifier.inactivated", auditable: primary)
  end

  test "rejects duplicate gtin on another product" do
    other = create_product!(sku: "P-OTHER-001", name: "Existing Product")
    ProductIdentifierService.add_identifier!(
      product: other,
      validation_family: "gtin",
      value: "9780306406157",
      primary: true
    )

    error = assert_raises(ProductIdentifierService::IdentifierError) do
      ProductIdentifierService.add_identifier!(
        product: @product,
        validation_family: "gtin",
        value: "978-0-306-40615-7",
        primary: true
      )
    end

    assert_match(/already assigned/i, error.message)
    assert_match(/Existing Product/, error.message)
  end

  test "freeform scoped uniqueness allows same value on different products" do
    other = create_product!(sku: "P-OTHER-002", name: "Other Product")
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "freeform",
      value: "VENDOR-1",
      freeform_scope: "vendor_catalog",
      primary: true
    )

    assert_nothing_raised do
      ProductIdentifierService.add_identifier!(
        product: other,
        validation_family: "freeform",
        value: "VENDOR-1",
        freeform_scope: "vendor_catalog",
        primary: true
      )
    end
  end

  test "sync_from_product_sku creates gtin primary when product has no identifiers" do
    @product.product_identifiers.destroy_all
    @product.update!(sku: "9780123456789")

    identifier = ProductIdentifierService.sync_from_product_sku!(product: @product, actor: @actor)

    assert_equal "gtin", identifier.validation_family
    assert_equal "9780123456789", identifier.normalized_identifier
    assert identifier.primary_identifier?
    assert_equal "9780123456789", @product.reload.sku
  end

  test "sync_from_product_sku updates primary when sku changes within same family" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780123456789",
      primary: true
    )
    @product.update!(sku: "9780123456786")

    ProductIdentifierService.sync_from_product_sku!(product: @product, actor: @actor)

    primary = @product.reload.primary_identifier
    assert_equal "9780123456786", primary.normalized_identifier
  end

  test "normalize_preview returns normalized string" do
    normalized = ProductIdentifierService.normalize_preview("isbn13", "978-0-123456-78-9")

    assert_equal "9780123456789", normalized
    assert_kind_of String, normalized
  end

  test "house update rejects non-201 values" do
    house = ProductIdentifierService.generate_house!(product: @product, actor: @actor)

    assert_raises(ProductIdentifierService::IdentifierError) do
      ProductIdentifierService.update_identifier!(
        identifier: house,
        value: "9780123456789",
        actor: @actor
      )
    end
  end

  test "house update rejects invalid 201 check digit" do
    house = ProductIdentifierService.generate_house!(product: @product, actor: @actor)

    assert_raises(ProductIdentifierService::IdentifierError) do
      ProductIdentifierService.update_identifier!(
        identifier: house,
        value: "2010000000010",
        actor: @actor
      )
    end
  end

  test "add_house_from_value rejects invalid 201 check digit" do
    assert_raises(ProductIdentifierService::IdentifierError) do
      ProductIdentifierService.send(
        :add_house_from_value!,
        product: @product,
        value: "2010000000010",
        primary: true,
        actor: @actor,
        source: "test"
      )
    end
  end

  test "invalid isbn10 does not create gtin alternate" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "isbn",
      value: "0123456780",
      primary: true,
      actor: @actor
    )

    assert_equal 1, @product.product_identifiers.active_records.count
    assert @product.product_identifiers.exists?(validation_family: "isbn")
    assert_not @product.product_identifiers.exists?(validation_family: "gtin")
  end

  test "invalid 978 isbn13 does not create isbn10 alternate" do
    ProductIdentifierService.add_identifier!(
      product: @product,
      validation_family: "gtin",
      value: "9780123456780",
      primary: true,
      actor: @actor
    )

    assert_equal 1, @product.product_identifiers.active_records.count
    assert @product.product_identifiers.exists?(validation_family: "gtin")
    assert_not @product.product_identifiers.exists?(validation_family: "isbn")
  end

  test "classify_product_sku treats 201 ean as house" do
    family, scope = ProductIdentifierService.send(:classify_product_sku, "2010000000012")

    assert_equal "house", family
    assert_nil scope
  end
end
