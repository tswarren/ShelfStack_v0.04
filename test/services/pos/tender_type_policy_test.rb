# frozen_string_literal: true

require "test_helper"

class Pos::TenderTypePolicyTest < ActiveSupport::TestCase
  setup do
    seed_phase7b_reference_data!
    @store = create_store!
    @user = create_user!
    @transaction = create_pos_transaction!(store: @store, workstation: create_workstation!(store: @store), user: @user)
  end

  test "returns base types without stored value permissions" do
    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_equal %w[cash card check], types
  end

  test "adds store credit on sale with redeem permission" do
    grant_permission!(@user, "pos.tenders.store_credit", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
  end

  test "adds store credit on refund with refund permission" do
    @transaction.update!(total_cents: -1000)
    grant_permission!(@user, "pos.refunds.store_credit", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
    refute_includes types, "gift_card"
  end

  test "adds store credit on refund with redeem permission only" do
    @transaction.update!(total_cents: -1000)
    grant_permission!(@user, "pos.tenders.store_credit", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
  end

  test "adds store credit on refund with cash refund permission only" do
    @transaction.update!(total_cents: -1000)
    grant_permission!(@user, "pos.tenders.refund", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
  end

  test "adds store credit on refund when user can complete transactions" do
    @transaction.update!(total_cents: -1000)
    grant_permission!(@user, "pos.transactions.complete", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
  end

  test "detects refund transaction from return lines before total is recalculated" do
    variant = create_product_variant!
    @transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: variant,
      quantity: -1,
      unit_price_cents: 1000,
      extended_price_cents: -1000
    )
    @transaction.update!(total_cents: 0, transaction_type: "return")
    grant_permission!(@user, "pos.tenders.store_credit", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "store_credit"
  end

  test "adds gift card with gift card permission" do
    grant_permission!(@user, "pos.tenders.gift_card", store: @store)

    types = Pos::TenderTypePolicy.allowed_types(@transaction, actor: @user, store: @store)

    assert_includes types, "gift_card"
  end
end
