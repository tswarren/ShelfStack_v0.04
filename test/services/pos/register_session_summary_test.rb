# frozen_string_literal: true

require "test_helper"

class Pos::RegisterSessionSummaryTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 3)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user, opening_cash_cents: 5000)
  end

  test "includes opening cash and net cash tenders" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @session)

    summary = Pos::RegisterSessionSummary.for(@session)
    assert_equal 5000, summary.opening_cash_cents
    assert summary.net_cash_tender_cents.positive?
    assert_equal summary.opening_cash_cents + summary.net_cash_tender_cents, summary.expected_closing_cash_cents
  end

  test "cash refund on return reduces expected closing cash" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @session)

    after_sale = Pos::RegisterSessionSummary.for(@session)

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: 1000,
        return_disposition: "return_to_stock",
        source_transaction_line: sale.pos_transaction_lines.first
      }]
    )
    Pos::RecalculateTransaction.call!(return_txn, business_date: @session.business_date)
    return_txn.pos_tenders.create!(tender_type: "cash", amount_cents: return_txn.total_cents)
    Pos::CompleteTransaction.call!(
      transaction: return_txn.reload,
      completed_by_user: @user,
      register_session: @session,
      confirmed_inactive: true
    )

    after_return = Pos::RegisterSessionSummary.for(@session)
    assert after_return.net_cash_tender_cents < after_sale.net_cash_tender_cents
    assert after_return.expected_closing_cash_cents < after_sale.expected_closing_cash_cents
  end
end
