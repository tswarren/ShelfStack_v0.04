# frozen_string_literal: true

require "test_helper"

class PosDraftLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "draft_lifecycle_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
  end

  test "create stamps draft with register session business date workstation cashier and user session" do
    assert_difference -> { PosTransaction.drafts.count }, 1 do
      post pos_transactions_path, params: { mode: "sale" }
    end

    assert_redirected_to edit_pos_transaction_path(PosTransaction.order(:id).last, mode: "sale")
    transaction = PosTransaction.order(:id).last

    assert_equal @register_session.id, transaction.pos_register_session_id
    assert_equal @register_session.business_date, transaction.business_date
    assert_equal @workstation.id, transaction.workstation_id
    assert_equal @cashier.id, transaction.cashier_user_id
    assert_not_nil transaction.user_session_id
  end

  test "second create resumes existing draft instead of creating duplicate" do
    post pos_transactions_path, params: { mode: "sale" }
    first = PosTransaction.order(:id).last

    assert_no_difference -> { PosTransaction.drafts.count } do
      post pos_transactions_path, params: { mode: "sale" }
    end

    assert_redirected_to edit_pos_transaction_path(first, mode: "sale")
  end


  test "create with legacy nil-session draft redirects to pos root without resuming" do
    legacy = create_pos_transaction!(store: @store, workstation: @workstation, user: @cashier)

    assert_no_difference -> { PosTransaction.drafts.count } do
      post pos_transactions_path, params: { mode: "sale" }
    end

    assert_redirected_to pos_root_path
    assert_match(/older draft needs review/, flash[:alert])
    assert_nil legacy.reload.pos_register_session_id
  end

  test "create without open register redirects to pos root" do
    Pos::RegisterSessionLifecycle.close!(
      session: @register_session,
      closed_by_user: @cashier,
      expected_closing_cash_cents: 0,
      counted_closing_cash_cents: 0
    )

    assert_no_difference -> { PosTransaction.count } do
      post pos_transactions_path, params: { mode: "sale" }
    end

    assert_redirected_to pos_root_path
    assert_match(/Open the register/, flash[:alert])
  end
end
