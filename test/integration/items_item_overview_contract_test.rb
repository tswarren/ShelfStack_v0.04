# frozen_string_literal: true

require "test_helper"

class Items::ItemOverviewContractTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "overviewuser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "overviewuser", password: "Password123!" }
    @product = create_product!
    @variant = create_product_variant!(product: @product)
  end

  test "overview renders report drill-down contract regions" do
    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#variant-availability"
    assert_select "#overview-summary-strip"
    assert_select ".ss-item-hero"
    assert_select "#warnings[hidden][aria-hidden='true']"
    assert_select ".ss-item-summary-cards", count: 0
    assert_select "#sales-history", count: 0
    assert_select "#receiving-history", count: 0
  end

  test "product_variant_id resolves item and highlights variant" do
    get items_item_path(product_variant_id: @variant.id, tab: "overview")

    assert_response :success
    assert_select "#variant-availability"
    assert_match @variant.sku, response.body
  end

  test "overview does not render receiving history on overview tab" do
    po = create_purchase_order!(store: @store, vendor: create_vendor!)
    receipt = create_receipt!(
      store: @store,
      vendor: po.vendor,
      attrs: { purchase_order: po },
      lines: [
        {
          product_variant: @variant,
          quantity_expected: 0,
          quantity_received: 2,
          quantity_accepted: 2,
          quantity_rejected: 0,
          unit_cost_cents: 900
        }
      ]
    )
    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#receiving-history", count: 0
    assert_no_match "Receipt ##{receipt.id}", response.body
  end

  test "overview keeps hidden warnings anchor without visible warnings panel" do
    @variant.update!(selling_price_cents: 0)

    get items_item_path(product_id: @product.id, tab: "overview")

    assert_response :success
    assert_select "#warnings[hidden][aria-hidden='true']"
    assert_select ".ss-operational-warnings", count: 0
  end
end
