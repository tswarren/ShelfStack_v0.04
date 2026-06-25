# frozen_string_literal: true

require "test_helper"

class Pos::DiscountApplicationServiceTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000 } ]
    )
    @line = @transaction.pos_transaction_lines.first
    @reason = DiscountReason.create!(reason_key: "app_test", name: "App Test #{SecureRandom.hex(4)}")
  end

  test "applies line amount discount" do
    application = Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @line,
      discount_reason: @reason,
      discount_method: "amount",
      entered_amount_cents: 100,
      actor: @user
    )

    @line.reload
    assert_equal 100, @line.line_discount_cents
    assert_equal 100, application.applied_discount_cents
  end

  test "requires note when reason requires note" do
    @reason.update!(requires_note: true)

    assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: @line,
        discount_reason: @reason,
        discount_method: "amount",
        entered_amount_cents: 100,
        actor: @user
      )
    end
  end

  test "requires manager authorization when reason requires approval" do
    @reason.update!(requires_authorization: true)

    error = assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: @line,
        discount_reason: @reason,
        discount_method: "amount",
        entered_amount_cents: 100,
        actor: @user
      )
    end

    assert_match(/Authorize discount/i, error.message)
  end

  test "rejects zero amount discount" do
    error = assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: @line,
        discount_reason: @reason,
        discount_method: "amount",
        entered_amount_cents: 0,
        actor: @user
      )
    end

    assert_match(/greater than zero/i, error.message)
  end

  test "rejects zero percent discount" do
    error = assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: @line,
        discount_reason: @reason,
        discount_method: "percent",
        entered_percent_bps: 0,
        actor: @user
      )
    end

    assert_match(/greater than zero/i, error.message)
  end

  test "rejects gift card line discount" do
    gift_card_line = @transaction.pos_transaction_lines.create!(
      line_number: 2,
      line_type: "gift_card_sale",
      quantity: 1,
      unit_price_cents: 2500,
      extended_price_cents: 2500
    )

    assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "line",
        line: gift_card_line,
        discount_reason: @reason,
        discount_method: "amount",
        entered_amount_cents: 100,
        actor: @user
      )
    end
  end

  test "applies transaction discount after line discount using remaining base" do
    Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @line,
      discount_reason: @reason,
      discount_method: "amount",
      entered_amount_cents: 100,
      actor: @user
    )
    txn_reason = DiscountReason.create!(reason_key: "txn_after_line", name: "Txn After Line #{SecureRandom.hex(4)}")

    application = Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "transaction",
      discount_reason: txn_reason,
      discount_method: "amount",
      entered_amount_cents: 90,
      actor: @user
    )

    @line.reload
    @transaction.reload
    assert_equal 100, @line.line_discount_cents
    assert_equal 90, @line.transaction_discount_cents
    assert_equal 90, application.applied_discount_cents
    assert_equal 90, @transaction.discount_cents
    assert_equal 810, @line.extended_price_cents
  end

  test "rejects transaction discount when no eligible base remains" do
    Pos::DiscountApplicationService.call!(
      transaction: @transaction,
      scope: "line",
      line: @line,
      discount_reason: @reason,
      discount_method: "amount",
      entered_amount_cents: 1000,
      actor: @user
    )

    assert_raises(Pos::DiscountApplicationService::Error) do
      Pos::DiscountApplicationService.call!(
        transaction: @transaction,
        scope: "transaction",
        discount_reason: @reason,
        discount_method: "amount",
        entered_amount_cents: 1,
        actor: @user
      )
    end
  end
end
