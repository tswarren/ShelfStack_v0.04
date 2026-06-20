# frozen_string_literal: true

require "test_helper"

class Pos::TenderSyncTest < ActiveSupport::TestCase
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
    result = Pos::TenderSync.call!(
      transaction: @transaction,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "20.00" } ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    assert_equal @transaction.total_cents, cash.amount_cents
    assert_equal 2000 - @transaction.total_cents, result.change_cents
    assert_equal 2000, Pos::TenderSync.tendered_cents_for(cash)
    Pos::TenderValidator.validate!(@transaction)
  end

  test "split tender with cash overpay calculates change from remaining balance" do
    result = Pos::TenderSync.call!(
      transaction: @transaction,
      tender_inputs: [
        { tender_type: "card", amount_dollars: "10.00" },
        { tender_type: "cash", amount_dollars: "10.00" }
      ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    remaining = @transaction.total_cents - 1000
    assert_equal remaining, cash.amount_cents
    assert_equal 1000 - remaining, result.change_cents
    assert_equal @transaction.total_cents, @transaction.pos_tenders.sum(&:amount_cents)
    Pos::TenderValidator.validate!(@transaction)
  end

  test "rejects insufficient cash tender" do
    error = assert_raises(Pos::TenderSync::Error) do
      Pos::TenderSync.call!(
        transaction: @transaction,
        tender_inputs: [ { tender_type: "cash", amount_dollars: "5.00" } ]
      )
    end

    assert_match(/insufficient cash/i, error.message)
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

    assert @transaction.total_cents.zero?

    Pos::TenderSync.call!(
      transaction: @transaction,
      tender_inputs: [ { tender_type: "cash", amount_dollars: "0.00" } ]
    )

    cash = @transaction.pos_tenders.find_by!(tender_type: "cash")
    assert_equal 0, cash.amount_cents
    Pos::TenderValidator.validate!(@transaction)
  end

  test "allows empty tenders when transaction total is zero" do
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

    Pos::TenderSync.call!(transaction: @transaction, tender_inputs: [])

    assert_empty @transaction.pos_tenders
    Pos::TenderValidator.validate!(@transaction)
  end
end
