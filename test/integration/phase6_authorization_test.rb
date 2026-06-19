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

    patch void_pos_transaction_path(transaction)
    assert_redirected_to pos_root_path
    follow_redirect!
    assert_match(/not authorized/i, flash[:alert].to_s)
  end
end
