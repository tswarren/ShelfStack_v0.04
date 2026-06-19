# frozen_string_literal: true

require "test_helper"

class PosHelperTest < ActionView::TestCase
  include PosHelper
  include SetupFormatHelper

  test "line discount breakdown separates line and order shares" do
    line = PosTransactionLine.new(
      quantity: 1,
      unit_price_cents: 1000,
      line_discount_cents: 100,
      extended_price_cents: 820
    )

    assert_equal 180, pos_line_total_discount_cents(line)
    assert_equal 80, pos_line_transaction_discount_cents(line)
    assert_equal "line $1.00, order $0.80", pos_line_discount_breakdown(line)
  end

  test "tax indicator uses store tax rate identifier" do
    line = PosTransactionLine.new(
      tax_rate_bps: 600,
      tax_cents: 54,
      tax_identifier_snapshot: "1"
    )

    assert_equal "1", pos_line_tax_indicator(line)
  end

  test "tax subtotals group by store tax rate short name" do
    transaction = PosTransaction.new
    transaction.pos_transaction_lines.build(
      quantity: 1,
      tax_cents: 60,
      store_tax_rate_short_name_snapshot: "State"
    )
    transaction.pos_transaction_lines.build(
      quantity: 1,
      tax_cents: 40,
      store_tax_rate_short_name_snapshot: "City"
    )

    subtotals = pos_transaction_tax_subtotals(transaction)
    assert_equal 2, subtotals.size
    assert_equal "City", subtotals.first.short_name
    assert_equal 40, subtotals.first.tax_cents
    assert_equal "State", subtotals.second.short_name
    assert_equal 60, subtotals.second.tax_cents
  end

  test "receipt change derives from cash tendered reference" do
    transaction = PosTransaction.new
    transaction.pos_tenders.build(tender_type: "cash", amount_cents: 1590, reference_number: "tendered_cents:2000")

    assert_equal 410, pos_receipt_change_cents(transaction)
  end
end
