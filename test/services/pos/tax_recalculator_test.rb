# frozen_string_literal: true

require "test_helper"

class Pos::TaxRecalculatorTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, line_type: "variant" } ]
    )
    @reason = TaxExceptionReason.create!(
      reason_key: "resale",
      name: "Resale Certificate",
      exception_type: "exemption",
      requires_certificate: true
    )
  end

  test "normal taxable line preserves normal and final tax" do
    Pos::RecalculateTransaction.call!(@transaction)

    line = @transaction.pos_transaction_lines.first

    assert_equal 60, line.normal_tax_cents
    assert_equal 60, line.tax_cents
    assert_equal "normal", line.applied_tax_source
    assert_equal 60, @transaction.normal_tax_cents
    assert_equal 60, @transaction.tax_cents
  end

  test "transaction exemption zeros final tax while preserving normal tax" do
    Pos::TaxExceptionApplicationService.call!(
      transaction: @transaction,
      scope: "transaction",
      tax_exception_reason: @reason,
      certificate_number: "MI-123456",
      actor: @user
    )

    line = @transaction.pos_transaction_lines.first.reload

    assert_equal 60, line.normal_tax_cents
    assert_equal 0, line.tax_cents
    assert_equal "transaction_exemption", line.applied_tax_source
    assert_equal 60, @transaction.reload.normal_tax_cents
    assert_equal 0, @transaction.tax_cents
  end

  test "gift card sale line stays non_taxable" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { line_type: "gift_card_sale", quantity: 1, unit_price_cents: 2500 } ]
    )

    Pos::RecalculateTransaction.call!(transaction)
    line = transaction.pos_transaction_lines.first

    assert_equal 0, line.normal_tax_cents
    assert_equal 0, line.tax_cents
    assert_equal "non_taxable", line.applied_tax_source
  end
end
