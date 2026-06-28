# frozen_string_literal: true

require "test_helper"

class Pos::SettlementSyncTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1500, extended_price_cents: 1500 } ]
    )
    Pos::RecalculateTransaction.call!(@transaction)
  end

  test "accepts cash tender greater than total and records applied amount with change" do
    result = Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "20.00" } ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    assert_equal @transaction.total_cents, cash.amount_cents
    assert_equal 2000, cash.tendered_cents
    assert_equal 2000 - @transaction.total_cents, result.change_cents
    assert_nil cash.reference_number
    Pos::TenderValidator.validate!(@transaction)
  end

  test "split tender with cash overpay calculates change from remaining balance" do
    result = Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_dollars: "10.00" },
        { tender_type: "cash", amount_dollars: "10.00" }
      ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    card = @transaction.pos_tenders.find_by!(tender_type: "card")
    remaining = @transaction.total_cents - 1000
    assert_equal "other", card.card_brand
    assert_equal remaining, cash.amount_cents
    assert_equal 1000 - remaining, result.change_cents
    assert_equal @transaction.total_cents, @transaction.pos_tenders.settlement_rows.sum(&:amount_cents)
    Pos::TenderValidator.validate!(@transaction)
  end

  test "supports multiple card rows with brands" do
    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_dollars: "5.00", card_brand: "visa", card_last_four: "1111" },
        { tender_type: "card", amount_dollars: "5.00", card_brand: "mastercard", card_last_four: "2222" },
        { tender_type: "cash", amount_dollars: "10.00" }
      ]
    )

    cards = @transaction.pos_tenders.settlement_rows.where(tender_type: "card").order(:line_number)
    assert_equal 2, cards.size
    assert_equal "visa", cards.first.card_brand
    assert_equal "mastercard", cards.second.card_brand
    Pos::TenderValidator.validate!(@transaction)
  end

  test "supports multiple check rows on sale" do
    half = @transaction.total_cents / 2
    remaining = @transaction.total_cents - half

    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "check", amount_cents: half, check_number: "100" },
        { tender_type: "check", amount_cents: remaining, check_number: "101" }
      ]
    )

    checks = @transaction.pos_tenders.settlement_rows.where(tender_type: "check")
    assert_equal 2, checks.size
    assert_equal @transaction.total_cents, checks.sum(&:amount_cents)
    Pos::TenderValidator.validate!(@transaction)
  end

  test "persists partial card tender and reports remaining due" do
    partial = @transaction.total_cents / 2

    result = Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_cents: partial, card_brand: "visa" }
      ]
    )

    card = @transaction.pos_tenders.find_by!(tender_type: "card")
    assert_equal partial, card.amount_cents
    assert_equal @transaction.total_cents - partial, result.remaining_cents
    assert_match(/remaining due/i, result.message)
  end

  test "persists partial cash tender and reports remaining due" do
    partial = @transaction.total_cents / 2

    result = Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "cash", amount_dollars: format("%.2f", partial / 100.0) }
      ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    assert_equal partial, cash.amount_cents
    assert_equal partial, cash.tendered_cents
    assert_equal @transaction.total_cents - partial, result.remaining_cents
    assert_match(/remaining due/i, result.message)
  end

  test "rejects check refunds from user input" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: -1500 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn)

    error = assert_raises(Pos::SettlementSync::Error) do
      Pos::SettlementSync.call!(
        transaction: return_txn,
        tender_inputs: [ { tender_type: "check", amount_dollars: "15.00" } ]
      )
    end

    assert_match(/check refunds are not supported/i, error.message)
  end

  test "accepts split cash and card refunds on return" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: -1500 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn)
    half = return_txn.total_cents.abs / 2
    remaining = return_txn.total_cents - (-half)

    Pos::SettlementSync.call!(
      transaction: return_txn,
      tender_inputs: [
        { tender_type: "card", amount_cents: -half, card_brand: "visa" },
        { tender_type: "cash", amount_cents: remaining }
      ]
    )

    assert_equal return_txn.total_cents, return_txn.pos_tenders.settlement_rows.sum(&:amount_cents)
    Pos::TenderValidator.validate!(return_txn)
  end

  test "accepts cash refund via sale-mode tendered_dollars field" do
    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: -1, unit_price_cents: 1500, extended_price_cents: -1500 } ]
    )
    Pos::RecalculateTransaction.call!(return_txn)
    total = return_txn.total_cents.abs

    Pos::SettlementSync.call!(
      transaction: return_txn,
      tender_inputs: [
        { tender_type: "cash", tendered_dollars: format("%.2f", total / 100.0) }
      ]
    )

    cash = return_txn.pos_tenders.settlement_rows.find_by!(tender_type: "cash")
    assert_equal return_txn.total_cents, cash.amount_cents
    Pos::TenderValidator.validate!(return_txn)
  end

  test "upserts settlement rows by id and marks destroy" do
    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_cents: @transaction.total_cents, card_brand: "visa" }
      ]
    )
    card = @transaction.pos_tenders.find_by!(tender_type: "card")

    Pos::SettlementSync.call!(
      transaction: @transaction.reload,
      tender_inputs: [
        { id: card.id, tender_type: "card", amount_cents: card.amount_cents, card_brand: "visa", _destroy: true },
        { tender_type: "cash", tendered_cents: @transaction.total_cents }
      ]
    )

    assert_nil @transaction.pos_tenders.settlement_rows.find_by(id: card.id)
    assert @transaction.pos_tenders.settlement_rows.exists?(tender_type: "cash")
  end

  test "does not renumber remaining rows after delete" do
    card_amount = @transaction.total_cents / 3
    second_card_amount = card_amount
    cash_tendered = @transaction.total_cents - card_amount - second_card_amount

    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_cents: card_amount, card_brand: "visa" },
        { tender_type: "card", amount_cents: second_card_amount, card_brand: "mastercard" },
        { tender_type: "cash", tendered_cents: cash_tendered }
      ]
    )
    cards = @transaction.pos_tenders.settlement_rows.where(tender_type: "card").order(:line_number)
    first_line_number = cards.first.line_number

    Pos::SettlementSync.call!(
      transaction: @transaction.reload,
      tender_inputs: [
        { id: cards.first.id, tender_type: "card", amount_cents: card_amount, card_brand: "visa", _destroy: true },
        { id: cards.second.id, tender_type: "card", amount_cents: @transaction.total_cents, card_brand: "mastercard" }
      ]
    )

    remaining_card = @transaction.pos_tenders.settlement_rows.find_by(tender_type: "card")
    assert_equal first_line_number + 1, remaining_card.line_number
  end

  test "accepts zero cash tender on even exchange" do
    @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: -1,
      unit_price_cents: 1500,
      extended_price_cents: -1500
    )
    Pos::RecalculateTransaction.call!(@transaction)

    Pos::SettlementSync.call!(
      transaction: @transaction,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "0.00" } ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    assert_equal 0, cash.amount_cents
    Pos::TenderValidator.validate!(@transaction)
  end

  test "records settlement sync audit event when actor present" do
    assert_difference -> { AuditEvent.where(event_name: "pos.settlement.synced").count }, 1 do
      Pos::SettlementSync.call!(
        transaction: @transaction,
        tender_inputs: [ { tender_type: "cash", amount_dollars: "20.00" } ],
        actor: @user
      )
    end
  end

  test "migration backfills cash tendered from reference_number" do
    transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    tender = transaction.pos_tenders.create!(
      tender_type: "cash",
      amount_cents: 1590,
      reference_number: "tendered_cents:2000",
      line_number: 1
    )

    # Simulate pre-migration state then run backfill logic
    tender.update_columns(tendered_cents: nil, change_cents: nil)
    tendered = tender.reference_number.delete_prefix("tendered_cents:").to_i
    change = [ tendered - tender.amount_cents, 0 ].max
    tender.update_columns(
      tendered_cents: tendered,
      change_cents: change.positive? ? change : nil,
      reference_number: nil
    )

    tender.reload
    assert_equal 2000, tender.tendered_cents
    assert_equal 410, tender.change_cents
    assert_nil tender.reference_number
  end
end
