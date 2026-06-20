# frozen_string_literal: true

require "test_helper"

class Phase6AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_permission!(@user, "pos.access", store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "pos workspace requires pos.access" do
    get pos_root_path
    assert_response :success
  end

  test "void requires pos.transactions.void" do
    grant_permission!(@user, "pos.transactions.view", store: @store)
    grant_permission!(@user, "pos.transactions.create", store: @store)
    grant_permission!(@user, "pos.transactions.update", store: @store)
    grant_permission!(@user, "pos.transactions.complete", store: @store)
    grant_permission!(@user, "pos.register_sessions.open", store: @store)
    grant_permission!(@user, "pos.tenders.cash", store: @store)

    variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: variant, user: @user, quantity: 2)
    session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: session)

    patch void_pos_transaction_path(transaction), params: { reason_code: "cashier_error" }
    assert_redirected_to pos_root_path
    follow_redirect!
    assert_match(/not authorized/i, flash[:alert].to_s)
  end

  test "void requires supervisor authorization when user has void permission" do
    grant_permission!(@user, "pos.transactions.view", store: @store)
    grant_permission!(@user, "pos.transactions.create", store: @store)
    grant_permission!(@user, "pos.transactions.update", store: @store)
    grant_permission!(@user, "pos.transactions.complete", store: @store)
    grant_permission!(@user, "pos.transactions.void", store: @store)
    grant_permission!(@user, "pos.register_sessions.open", store: @store)
    grant_permission!(@user, "pos.register_sessions.close", store: @store)
    grant_permission!(@user, "pos.tenders.cash", store: @store)

    variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: variant, user: @user, quantity: 2)
    session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: session)

    patch void_pos_transaction_path(transaction), params: { reason_code: "cashier_error" }

    assert_redirected_to pos_transaction_path(transaction)
    assert_match(/Supervisor authorization required/i, flash[:alert].to_s)
    refute transaction.reload.voided?

    authorization = grant_void_authorization!(transaction: transaction, requested_by: @user)
    patch void_pos_transaction_path(transaction), params: {
      reason_code: "cashier_error",
      pos_authorization_id: authorization.id
    }

    assert_redirected_to pos_transaction_path(transaction)
    assert transaction.reload.voided?
  end
end
