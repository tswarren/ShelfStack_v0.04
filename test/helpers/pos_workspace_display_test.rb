# frozen_string_literal: true

require "test_helper"

class PosWorkspaceDisplayTest < ActionView::TestCase
  include PosHelper
  include SetupFormatHelper

  test "tax subtotals include taxable base and rate" do
    store = create_store!
    workstation = create_workstation!(store: store)
    user = create_user!
    variant = create_product_variant!(selling_price_cents: 1000)
    tax_category = variant.sub_department.default_tax_category
    store_tax_rate = create_store_tax_rate!(store: store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: store, tax_category: tax_category, store_tax_rate: store_tax_rate)

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
      extended_price_cents: 1000,
      tax_cents: 60,
      tax_rate_bps: 600,
      store_tax_rate_short_name_snapshot: "Taxable"
    )

    subtotals = pos_transaction_tax_subtotals(transaction)
    subtotal = subtotals.first

    assert_equal "Taxable", subtotal.short_name
    assert_equal 60, subtotal.tax_cents
    assert_equal 1000, subtotal.taxable_base_cents
    assert_equal 600, subtotal.tax_rate_bps
    assert_equal "6.00%", pos_format_tax_rate_bps(subtotal.tax_rate_bps)
  end

  test "item counts sum sold and returned quantities" do
    store = create_store!
    workstation = create_workstation!(store: store)
    user = create_user!
    variant = create_product_variant!

    transaction = PosTransaction.create!(
      store: store,
      workstation: workstation,
      cashier_user: user,
      status: "draft",
      business_date: Date.current
    )
    transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: variant,
      product: variant.product,
      quantity: 2,
      unit_price_cents: 500,
      extended_price_cents: 1000
    )
    transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "variant",
      product_variant: variant,
      product: variant.product,
      quantity: -1,
      unit_price_cents: 500,
      extended_price_cents: -500
    )

    counts = pos_transaction_item_counts(transaction)

    assert_equal 2, counts[:sold]
    assert_equal 1, counts[:returned]
  end

  test "line tax display shows label without amount when tax is zero" do
    line = PosTransactionLine.new(
      tax_cents: 0,
      store_tax_rate_short_name_snapshot: "Non-Tax"
    )

    display = pos_line_tax_display(line)

    assert_equal "Non-Tax", display[:label]
    assert_nil display[:amount_cents]
  end

  test "line tax display shows label and amount when taxed" do
    line = PosTransactionLine.new(
      tax_cents: 42,
      store_tax_rate_short_name_snapshot: "Taxable"
    )

    display = pos_line_tax_display(line)

    assert_equal "Taxable", display[:label]
    assert_equal 42, display[:amount_cents]
  end
end
