# frozen_string_literal: true

require "test_helper"

class Pos::CommandCarryForwardTest < ActiveSupport::TestCase
  test "edit_path includes carry-forward params" do
    store = create_store!
    transaction = create_pos_transaction!(
      store: store,
      workstation: create_workstation!(store: store),
      user: create_user!
    )

    path = Pos::CommandCarryForward.edit_path(
      transaction: transaction,
      carry_forward: "gift_card",
      amount_cents: 5000
    )

    assert_includes path, "carry_forward=gift_card"
    assert_includes path, "amount_cents=5000"
  end

  test "carry_forward_for maps route actions" do
    assert_equal "open_ring", Pos::CommandCarryForward.carry_forward_for(:open_ring_offer)
    assert_equal "gift_card", Pos::CommandCarryForward.carry_forward_for(:gift_card_sale_offer)
    assert_equal "return", Pos::CommandCarryForward.carry_forward_for(:return_drawer_offer)
    assert_equal "pickup", Pos::CommandCarryForward.carry_forward_for(:pickup_drawer_offer)
  end

  test "edit_path includes receipt number and pickup mode" do
    store = create_store!
    transaction = create_pos_transaction!(
      store: store,
      workstation: create_workstation!(store: store),
      user: create_user!
    )

    path = Pos::CommandCarryForward.edit_path(
      transaction: transaction,
      carry_forward: "return",
      receipt_number: "001-001-000042",
      mode: "sale"
    )

    assert_includes path, "carry_forward=return"
    assert_includes path, "receipt_number=001-001-000042"

    pickup_path = Pos::CommandCarryForward.edit_path(
      transaction: transaction,
      carry_forward: "pickup",
      mode: "sale"
    )

    assert_includes pickup_path, "mode=sale"
    assert_includes pickup_path, "carry_forward=pickup"
    assert_not_includes pickup_path, "mode=pickup"
  end

  test "mode_for keeps command-driven carry-forward in sale mode" do
    assert_equal "sale", Pos::CommandCarryForward.mode_for(:pickup_drawer_offer)
    assert_equal "sale", Pos::CommandCarryForward.mode_for(:return_drawer_offer)
  end
end
