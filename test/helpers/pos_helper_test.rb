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
      extended_price_cents: 820,
      transaction_discount_cents: 80
    )

    assert_equal 180, pos_line_total_discount_cents(line)
    assert_equal 80, pos_line_transaction_discount_cents(line)
    assert_equal "line $1.00, order $0.80", pos_line_discount_breakdown(line)
  end

  test "line discount breakdown includes transaction allocations when line applications exist" do
    reason = DiscountReason.create!(reason_key: "helper_mix", name: "Helper Mix")
    user = create_user!
    store = create_store!
    workstation = create_workstation!(store: store)
    variant = create_product_variant!
    transaction = PosTransaction.create!(
      store: store,
      workstation: workstation,
      cashier_user: user,
      status: "draft",
      business_date: Date.current
    )
    line = transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: variant,
      product: variant.product,
      quantity: 1,
      unit_price_cents: 1000,
      extended_price_cents: 820,
      line_discount_cents: 100,
      transaction_discount_cents: 80
    )
    line_app = PosDiscountApplication.create!(
      pos_transaction: transaction,
      pos_transaction_line: line,
      discount_reason: reason,
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 100,
      applied_discount_cents: 100,
      stack_order: 1,
      applied_by_user: user,
      applied_at: Time.current
    )
    txn_app = PosDiscountApplication.create!(
      pos_transaction: transaction,
      discount_reason: reason,
      scope: "transaction",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 80,
      applied_discount_cents: 80,
      stack_order: 2,
      applied_by_user: user,
      applied_at: Time.current
    )
    PosDiscountAllocation.create!(
      pos_discount_application: line_app,
      pos_transaction: transaction,
      pos_transaction_line: line,
      scope: "line",
      allocation_base_cents: 1000,
      allocated_discount_cents: 100,
      line_number_snapshot: 1
    )
    PosDiscountAllocation.create!(
      pos_discount_application: txn_app,
      pos_transaction: transaction,
      pos_transaction_line: line,
      scope: "transaction",
      allocation_base_cents: 900,
      allocated_discount_cents: 80,
      line_number_snapshot: 1
    )

    assert_includes pos_line_discount_breakdown(line.reload), "Helper Mix $1.00"
    assert_includes pos_line_discount_breakdown(line), "order Helper Mix $0.80"
  end

  test "receipt tax subtotals use identifier and short name label" do
    transaction = PosTransaction.new
    transaction.pos_transaction_lines.build(
      quantity: 1,
      tax_cents: 30,
      tax_identifier_snapshot: "T",
      store_tax_rate_short_name_snapshot: "Sales Tax"
    )

    subtotals = pos_receipt_tax_subtotals(transaction)
    assert_equal 1, subtotals.size
    assert_equal "T - Sales Tax", subtotals.first.label
    assert_equal 30, subtotals.first.tax_cents
  end

  test "receipt savings total sums item and order discounts" do
    transaction = PosTransaction.new(discount_cents: 200)
    transaction.pos_transaction_lines.build(quantity: 1, line_discount_cents: 100)

    assert_equal 300, pos_receipt_savings_total(transaction)
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

  test "receipt change derives from change_cents column" do
    transaction = PosTransaction.new
    transaction.pos_tenders.build(
      tender_type: "cash",
      amount_cents: 1590,
      tendered_cents: 2000,
      change_cents: 410,
      line_number: 1
    )

    assert_equal 410, pos_receipt_change_cents(transaction)
  end

  test "receipt change derives from legacy cash tendered reference" do
    transaction = PosTransaction.new
    transaction.pos_tenders.build(tender_type: "cash", amount_cents: 1590, reference_number: "tendered_cents:2000", line_number: 1)

    assert_equal 410, pos_receipt_change_cents(transaction)
  end

  test "receipt label includes card brand and last four" do
    tender = PosTender.new(tender_type: "card", card_brand: "visa", card_last_four: "1122", amount_cents: 1000, line_number: 1)

    assert_equal "Visa ending 1122", pos_tender_receipt_label(tender)
  end

  test "receipt label includes check number" do
    tender = PosTender.new(tender_type: "check", check_number: "5001", amount_cents: 1000, line_number: 1)

    assert_equal "Check #5001", pos_tender_receipt_label(tender)
  end

  test "settlement row summary includes card brand and amount" do
    row = PosTender.new(tender_type: "card", card_brand: "visa", card_last_four: "1122", amount_cents: 1000, line_number: 1)
    transaction = PosTransaction.new(total_cents: 1000)

    assert_equal "Card – Visa 1122 — $10.00", pos_settlement_row_summary(row, transaction)
  end

  test "price editable for sale lines and no receipt returns but not receipted returns" do
    sale_line = PosTransactionLine.new(quantity: 1, line_type: "variant")
    no_receipt_return = PosTransactionLine.new(quantity: -1, line_type: "variant")
    receipted_return = PosTransactionLine.new(
      quantity: -1,
      line_type: "variant",
      source_transaction_line_id: 99
    )

    assert pos_line_price_editable?(sale_line)
    assert pos_line_price_editable?(no_receipt_return)
    refute pos_line_price_editable?(receipted_return)
  end

  test "receipt line header uses net extended price" do
    line = PosTransactionLine.new(
      quantity: 1,
      unit_price_cents: 450,
      line_discount_cents: 45,
      extended_price_cents: 405
    )

    assert_equal 405, pos_receipt_line_header_amount_cents(line)
    assert_equal 450, pos_receipt_line_list_amount_cents(line)
    assert_equal 450, pos_receipt_line_unit_list_amount_cents(line)
  end

  test "receipt line unit list price is per unit for multi-qty lines" do
    line = PosTransactionLine.new(
      quantity: 3,
      unit_price_cents: 1500,
      line_discount_cents: 150,
      extended_price_cents: 4050
    )

    assert_equal 4500, pos_receipt_line_list_amount_cents(line)
    assert_equal 1500, pos_receipt_line_unit_list_amount_cents(line)
    assert pos_receipt_line_show_list_detail?(line)
  end

  test "receipt line unit paid price reflects net extended price per unit" do
    line = PosTransactionLine.new(
      quantity: 3,
      unit_price_cents: 550,
      line_discount_cents: 39,
      extended_price_cents: 1011
    )

    assert_equal 550, pos_receipt_line_unit_list_amount_cents(line)
    assert_equal 337, pos_receipt_line_unit_paid_amount_cents(line)
  end

  test "receipt line detail flags distinguish list and item discount" do
    undiscounted = PosTransactionLine.new(quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000)
    line_discount = PosTransactionLine.new(
      quantity: 1,
      unit_price_cents: 450,
      line_discount_cents: 45,
      extended_price_cents: 405
    )
    order_discount_only = PosTransactionLine.new(
      quantity: 1,
      unit_price_cents: 1000,
      line_discount_cents: 0,
      extended_price_cents: 900,
      transaction_discount_cents: 100
    )
    return_line = PosTransactionLine.new(quantity: -1, unit_price_cents: 1000, extended_price_cents: -1000)

    refute pos_receipt_line_show_list_detail?(undiscounted)
    assert_empty pos_receipt_line_discount_details(undiscounted)

    assert pos_receipt_line_show_list_detail?(line_discount)
    assert_equal [ "Item discount" ], pos_receipt_line_discount_details(line_discount).map(&:label)

    assert pos_receipt_line_show_list_detail?(order_discount_only)
    assert_equal [ "Order discount" ], pos_receipt_line_discount_details(order_discount_only).map(&:label)
    assert_equal 100, pos_receipt_line_discount_details(order_discount_only).first.amount_cents

    assert_empty pos_receipt_line_discount_details(return_line)
  end

  test "receipt line discount details use per-unit amounts for multi-quantity lines" do
    line_discount = PosTransactionLine.new(
      quantity: 2,
      unit_price_cents: 1500,
      line_discount_cents: 100,
      extended_price_cents: 2900
    )
    order_discount_only = PosTransactionLine.new(
      quantity: 3,
      unit_price_cents: 1000,
      line_discount_cents: 0,
      extended_price_cents: 2700,
      transaction_discount_cents: 300
    )

    assert_equal 50, pos_receipt_line_discount_details(line_discount).first.amount_cents
    assert_equal 100, pos_receipt_line_discount_details(order_discount_only).first.amount_cents
  end

  test "receipt line discount details include structured line and order allocations" do
    reason = DiscountReason.create!(reason_key: "receipt_mix", name: "Receipt Mix")
    user = create_user!
    store = create_store!
    workstation = create_workstation!(store: store)
    variant = create_product_variant!
    transaction = PosTransaction.create!(
      store: store,
      workstation: workstation,
      cashier_user: user,
      status: "completed",
      business_date: Date.current
    )
    line = transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: variant,
      product: variant.product,
      quantity: 1,
      unit_price_cents: 1000,
      extended_price_cents: 810,
      line_discount_cents: 100,
      transaction_discount_cents: 90
    )
    line_app = PosDiscountApplication.create!(
      pos_transaction: transaction,
      pos_transaction_line: line,
      discount_reason: reason,
      scope: "line",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 100,
      applied_discount_cents: 100,
      stack_order: 1,
      applied_by_user: user,
      applied_at: Time.current
    )
    txn_app = PosDiscountApplication.create!(
      pos_transaction: transaction,
      discount_reason: reason,
      scope: "transaction",
      source: "manual",
      discount_method: "amount",
      entered_amount_cents: 90,
      applied_discount_cents: 90,
      stack_order: 2,
      applied_by_user: user,
      applied_at: Time.current
    )
    PosDiscountAllocation.create!(
      pos_discount_application: line_app,
      pos_transaction: transaction,
      pos_transaction_line: line,
      scope: "line",
      allocation_base_cents: 1000,
      allocated_discount_cents: 100,
      line_number_snapshot: 1
    )
    PosDiscountAllocation.create!(
      pos_discount_application: txn_app,
      pos_transaction: transaction,
      pos_transaction_line: line,
      scope: "transaction",
      allocation_base_cents: 900,
      allocated_discount_cents: 90,
      line_number_snapshot: 1
    )

    labels = pos_receipt_line_discount_details(line.reload).map(&:label)
    assert_includes labels, "Receipt Mix"
    assert_includes labels, "Order discount — Receipt Mix"
  end

  test "receipt line quantity detail shows for multi-qty merchandise lines only" do
    single = PosTransactionLine.new(line_type: "variant", quantity: 1, unit_price_cents: 1500)
    multi = PosTransactionLine.new(line_type: "variant", quantity: 2, unit_price_cents: 1500)
    multi_return = PosTransactionLine.new(line_type: "variant", quantity: -2, unit_price_cents: 1500)
    gift_card = PosTransactionLine.new(line_type: "gift_card_sale", quantity: 1, unit_price_cents: 2500)

    refute pos_receipt_line_show_quantity_detail?(single)
    assert pos_receipt_line_show_quantity_detail?(multi)
    assert pos_receipt_line_show_quantity_detail?(multi_return)
    refute pos_receipt_line_show_quantity_detail?(gift_card)
  end

  test "receipt discounted subtotal sums signed extended prices" do
    transaction = PosTransaction.new(subtotal_cents: 3000, discount_cents: 300)
    transaction.pos_transaction_lines.build(
      quantity: 1,
      unit_price_cents: 2000,
      line_discount_cents: 100,
      extended_price_cents: 1700
    )
    transaction.pos_transaction_lines.build(
      quantity: -1,
      unit_price_cents: 1000,
      extended_price_cents: -1000
    )

    assert_equal 700, pos_receipt_discounted_subtotal_cents(transaction)
  end

  test "transaction item counts sum sold and returned quantities" do
    transaction = PosTransaction.new
    transaction.pos_transaction_lines.build(quantity: 2)
    transaction.pos_transaction_lines.build(quantity: 1)
    transaction.pos_transaction_lines.build(quantity: -1)

    assert_equal 3, pos_transaction_items_sold_count(transaction)
    assert_equal 1, pos_transaction_items_returned_count(transaction)
  end
end
