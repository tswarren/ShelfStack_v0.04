# frozen_string_literal: true

require "test_helper"

class Phase5AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @other_store = create_store!(store_number: "002", name: "Other Store")
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_permission!(@user, "orders.access", store: @store)
  end

  def login!
    login_user!(@user, workstation: @workstation)
  end

  test "user without orders access is redirected to locked out" do
    user = create_user!(username: "no_orders")
    login_user!(user, workstation: @workstation)
    get orders_root_path
    assert_redirected_to orders_locked_out_path
  end

  test "user with orders access can view orders home" do
    login!
    get orders_root_path
    assert_response :success
  end

  test "purchase orders require view permission" do
    login!
    get orders_purchase_orders_path
    assert_redirected_to root_path
  end

  test "purchase orders viewable with permission" do
    grant_permission!(@user, "orders.purchase_orders.view", store: @store)
    login!
    get orders_purchase_orders_path
    assert_response :success
  end

  test "receipt post requires post permission" do
    grant_permission!(@user, "orders.receipts.view", store: @store)
    grant_permission!(@user, "orders.receipts.create", store: @store)
    vendor = create_vendor!
    variant = create_product_variant!(inventory_behavior: "standard_physical")
    receipt = create_receipt!(
      store: @store,
      vendor: vendor,
      lines: [
        {
          product_variant: variant,
          quantity_expected: 0,
          quantity_received: 1,
          quantity_accepted: 1,
          quantity_rejected: 0
        }
      ]
    )
    login!
    patch post_orders_receipt_path(receipt)
    assert_redirected_to root_path
  end

  test "store scoped permission does not grant access in other store context" do
    grant_permission!(@user, "orders.purchase_orders.view", store: @other_store)
    login!
    get orders_purchase_orders_path
    assert_redirected_to root_path
  end
end
