# frozen_string_literal: true

require "test_helper"

class Pos::LineTaxOverrideIntegrationTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    @non_taxable_category = TaxCategory.create!(name: "Non-Taxable Override #{SecureRandom.hex(3)}", short_name: "NTO")
    @zero_rate = create_store_tax_rate!(store: @store, tax_rate_bps: 0, name: "Zero #{SecureRandom.hex(2)}", short_name: "Z0", tax_identifier: "Z")
    create_store_tax_category_rate!(store: @store, tax_category: @non_taxable_category, store_tax_rate: @zero_rate)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, line_type: "variant" } ]
    )
    @reason = TaxExceptionReason.create!(
      reason_key: "wrong_tax_category",
      name: "Wrong Tax Category",
      exception_type: "rate_override",
      requires_note: true
    )
  end

  test "line override changes applied tax while preserving normal tax" do
    Pos::TaxExceptionApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @transaction.pos_transaction_lines.first,
      tax_exception_reason: @reason,
      override_tax_category: @non_taxable_category,
      note: "Should be non-taxable",
      actor: @user
    )

    line = @transaction.pos_transaction_lines.first.reload

    assert_equal 60, line.normal_tax_cents
    assert_equal 0, line.tax_cents
    assert_equal "line_override", line.applied_tax_source
    assert_equal @non_taxable_category.id, line.tax_category_id
  end

  test "transaction exemption wins over line override for final tax" do
    exemption_reason = TaxExceptionReason.create!(
      reason_key: "resale",
      name: "Resale Certificate",
      exception_type: "exemption",
      requires_certificate: true
    )

    line = @transaction.pos_transaction_lines.first
    Pos::TaxExceptionApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: line,
      tax_exception_reason: @reason,
      override_tax_category: @non_taxable_category,
      note: "Wrong category",
      actor: @user
    )
    Pos::TaxExceptionApplicationService.call!(
      transaction: @transaction,
      scope: "transaction",
      tax_exception_reason: exemption_reason,
      certificate_number: "MI-999",
      actor: @user
    )

    line.reload

    assert_equal 0, line.tax_cents
    assert_equal "transaction_exemption", line.applied_tax_source
    assert_equal 1, line.pos_line_tax_overrides.active_records.count
    assert_equal 1, @transaction.pos_tax_exemptions.active_records.count
  end
end
