# frozen_string_literal: true

require "test_helper"

class PosTenderTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
  end

  test "requires line_number unique per transaction" do
    create_pos_tender!(@transaction, tender_type: "cash", amount_cents: 100, line_number: 1)

    duplicate = @transaction.pos_tenders.build(tender_type: "card", amount_cents: 100, line_number: 1, card_brand: "visa")
    refute duplicate.valid?
    assert_includes duplicate.errors[:line_number], "has already been taken"
  end

  test "requires card_brand for card tenders" do
    tender = @transaction.pos_tenders.build(tender_type: "card", amount_cents: 100, line_number: 1)
    refute tender.valid?
    assert_includes tender.errors[:card_brand], "can't be blank"

    tender.card_brand = "visa"
    assert tender.valid?
  end

  test "validates card_last_four format when present" do
    tender = @transaction.pos_tenders.build(
      tender_type: "card",
      amount_cents: 100,
      line_number: 1,
      card_brand: "visa",
      card_last_four: "12ab"
    )
    refute tender.valid?
    assert_includes tender.errors[:card_last_four], "is invalid"
  end

  test "allows negative check row when reversing original tender" do
    original = create_pos_tender!(@transaction, tender_type: "check", amount_cents: 500, check_number: "1001")
    reversal = @transaction.pos_tenders.build(
      tender_type: "check",
      amount_cents: -500,
      line_number: PosTender.next_line_number_for(@transaction),
      check_number: "1001",
      reverses_tender: original
    )

    assert reversal.valid?
  end

  test "tendered_display_cents prefers column over legacy reference" do
    tender = PosTender.new(
      tender_type: "cash",
      amount_cents: 1000,
      tendered_cents: 1500,
      reference_number: "tendered_cents:2000",
      line_number: 1
    )

    assert_equal 1500, tender.tendered_display_cents
  end

  test "settlement_rows excludes reversal rows" do
    original = create_pos_tender!(@transaction, tender_type: "cash", amount_cents: 1000)
    create_pos_tender!(
      @transaction,
      tender_type: "cash",
      amount_cents: -1000,
      reverses_tender: original
    )

    assert_equal [ original.id ], @transaction.pos_tenders.settlement_rows.pluck(:id)
  end

  test "next_line_number_for returns max plus one" do
    create_pos_tender!(@transaction, tender_type: "cash", amount_cents: 100, line_number: 3)
    assert_equal 4, PosTender.next_line_number_for(@transaction)
  end
end
