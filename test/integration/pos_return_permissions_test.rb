# frozen_string_literal: true

require "test_helper"

class PosReturnPermissionsTest < ActionDispatch::IntegrationTest
  include Phase6TestHelper

  setup do
    @cashier = create_user!(username: "return_perm_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, grant_permissions: false)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]

    grant_permission!(@cashier, "pos.access", store: @store)
    grant_permission!(@cashier, "pos.lines.add", store: @store)
    grant_permission!(@cashier, "pos.returns.receipted", store: @store)
    grant_permission!(@cashier, "pos.transactions.update", store: @store)
    grant_permission!(@cashier, "pos.transactions.create", store: @store)

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )
  end

  test "workspace add no receipt line forbidden without pos.returns.no_receipt" do
    assert_no_difference -> { PosTransaction.count } do
      post pos_workspace_add_no_receipt_line_path,
           params: { product_variant_id: @variant.id, quantity: -1 }
    end

    assert_redirected_to pos_root_path
    assert_match(/not authorized/i, flash[:alert])
  end

  test "transaction add line with return mode forbidden without pos.returns.no_receipt" do
    post add_line_pos_transaction_path(@transaction),
         params: { product_variant_id: @variant.id, quantity: -1, return_mode: true }

    assert_redirected_to pos_root_path
    assert_match(/not authorized/i, flash[:alert])
    assert_empty @transaction.reload.pos_transaction_lines
  end

  test "edit page hides no receipt workflow without pos.returns.no_receipt" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, "No-receipt returns require additional permission"
    refute_includes response.body, "Add open-ring return"
  end
end
