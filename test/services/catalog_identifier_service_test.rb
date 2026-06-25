# frozen_string_literal: true

require "test_helper"

class CatalogIdentifierServiceTest < ActiveSupport::TestCase
  setup do
    @item = CatalogItem.create!(
      catalog_item_type: "book",
      title: "Identifier Test",
      publication_status: "active",
      format: create_format!(format_key: "id_test_#{SecureRandom.hex(2)}"),
      active: true
    )
  end

  test "normalizes standard identifiers to digits only" do
    identifier = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "978-0-123456-78-9",
      primary: true
    )
    assert_equal "9780123456789", identifier.normalized_identifier
  end

  test "validation_preview reports invalid isbn13" do
    preview = CatalogIdentifierService.validation_preview(
      identifier_type: "isbn13",
      value: "9780123456780"
    )

    assert_equal "9780123456780", preview[:normalized]
    assert_equal false, preview[:valid]
    assert_match(/invalid/i, preview[:message])
  end

  test "invalid isbn13 saves with warning" do
    identifier = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456780",
      primary: true
    )
    assert_equal false, identifier.valid_check_digit
    assert_match(/invalid/i, identifier.validation_message)
  end

  test "isbn10 creates isbn13 primary" do
    actor = create_user!(username: "isbnactor")
    CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn10",
      value: "0123456789",
      primary: true,
      actor: actor
    )

    isbn10 = @item.catalog_item_identifiers.find_by(identifier_type: "isbn10")
    isbn13 = @item.catalog_item_identifiers.find_by(identifier_type: "isbn13", normalized_identifier: "9780123456786")

    assert_equal "0123456789", isbn10.normalized_identifier
    assert_not isbn10.primary_identifier?
    assert isbn13.primary_identifier?
    assert AuditEvent.exists?(event_name: "catalog_item_identifier.isbn10_converted")
  end

  test "publisher number preserves display and normalizes searchable value" do
    identifier = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "publisher_number",
      value: "ABC 123-45",
      primary: true
    )
    assert_equal "ABC 123-45", identifier.identifier_value
    assert_equal "ABC12345", identifier.normalized_identifier
    assert_nil identifier.valid_check_digit
  end

  test "generate local identifier" do
    actor = create_user!(username: "localactor")
    identifier = CatalogIdentifierService.generate_local!(catalog_item: @item, actor: actor)
    assert_match(/\AL\d{9}\z/, identifier.normalized_identifier)
    assert identifier.primary_identifier?
    assert AuditEvent.exists?(event_name: "catalog_item_identifier.local_generated", auditable: identifier)
  end

  test "set primary clears previous primary" do
    actor = create_user!(username: "primaryactor")
    first = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456789",
      primary: true,
      actor: actor
    )
    second = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "publisher_number",
      value: "SECOND-ID",
      primary: false
    )

    CatalogIdentifierService.set_primary!(identifier: second, actor: actor)
    assert_not first.reload.primary_identifier?
    assert second.reload.primary_identifier?
    assert AuditEvent.exists?(event_name: "catalog_item_identifier.primary_changed", auditable: second)
  end

  test "update identifier renormalizes value" do
    actor = create_user!(username: "updateactor")
    identifier = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456789",
      primary: true,
      actor: actor
    )

    CatalogIdentifierService.update_identifier!(
      identifier: identifier,
      value: "978-0-306-40615-7",
      actor: actor
    )

    assert_equal "9780306406157", identifier.reload.normalized_identifier
    assert AuditEvent.exists?(event_name: "catalog_item_identifier.updated", auditable: identifier)
  end

  test "remove identifier inactivates record and reassigns primary" do
    actor = create_user!(username: "removeactor")
    primary = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456789",
      primary: true,
      actor: actor
    )
    secondary = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "publisher_number",
      value: "ALT-ID",
      primary: false
    )

    CatalogIdentifierService.remove_identifier!(identifier: primary, actor: actor)

    assert_not primary.reload.active?
    assert secondary.reload.primary_identifier?
    assert AuditEvent.exists?(event_name: "catalog_item_identifier.inactivated", auditable: primary)
  end

  test "remove only identifier is rejected" do
    identifier = CatalogIdentifierService.add_identifier!(
      catalog_item: @item,
      identifier_type: "isbn13",
      value: "9780123456789",
      primary: true
    )

    assert_raises(CatalogIdentifierService::IdentifierError) do
      CatalogIdentifierService.remove_identifier!(identifier: identifier)
    end
  end

  test "rejects duplicate standard identifier on another catalog item" do
    other = CatalogItem.create!(
      catalog_item_type: "book",
      title: "Existing Book",
      publication_status: "active",
      format: create_format!(format_key: "dup_fmt_#{SecureRandom.hex(2)}"),
      active: true
    )
    CatalogIdentifierService.add_identifier!(
      catalog_item: other,
      identifier_type: "isbn13",
      value: "9780306406157",
      primary: true
    )

    error = assert_raises(CatalogIdentifierService::IdentifierError) do
      CatalogIdentifierService.add_identifier!(
        catalog_item: @item,
        identifier_type: "isbn13",
        value: "978-0-306-40615-7",
        primary: true
      )
    end

    assert_match(/already assigned/i, error.message)
    assert_match(/Existing Book/, error.message)
  end
end
