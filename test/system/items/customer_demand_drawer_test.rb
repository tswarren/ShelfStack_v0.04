# frozen_string_literal: true

require "application_system_test_case"

class ItemsCustomerDemandDrawerSystemTest < ApplicationSystemTestCase
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "customer_requests.access", store: @store)
    grant_permission!(@user, "customer_requests.create", store: @store)
    grant_permission!(@user, "inventory_reservations.create", store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @product = @variant.product

    system_login!(@user, workstation: @workstation)
  end

  def visit_item_operations!
    visit items_item_path(product_id: @product.id, tab: "operations")
    assert_text "Variant operations", wait: 10
  end

  test "shared demand drawer opens from operations and restores focus on close" do
    visit_item_operations!

    assert_selector "#item-demand-drawer", visible: :hidden
    assert_includes page.body, "ss-drawer"

    hold_button = find("button", text: "Hold for customer", match: :first)
    hold_button.click

    assert_no_selector "#item-demand-drawer[hidden]"
    assert_text @variant.sku

    find("#item-demand-drawer .ss-drawer-close").click
    assert_selector "#item-demand-drawer[hidden]", visible: :all
    assert_equal hold_button, page.active_element
  end

  test "shared demand drawer closes on escape when form is clean" do
    visit_item_operations!

    hold_button = find("button", text: "Hold for customer", match: :first)
    hold_button.click
    assert_no_selector "#item-demand-drawer[hidden]"

    send_escape
    assert_selector "#item-demand-drawer[hidden]", visible: :all
    assert_equal hold_button, page.active_element
  end

  test "shared demand drawer stays open on escape when form is dirty" do
    visit_item_operations!

    find("button", text: "Hold for customer", match: :first).click
    find("#item-demand-drawer input[name='quantity']").fill_in with: "2"

    send_escape
    assert_no_selector "#item-demand-drawer[hidden]"
  end

  test "shared demand drawer closes via cancel when form is dirty" do
    visit_item_operations!

    hold_button = find("button", text: "Hold for customer", match: :first)
    hold_button.click
    find("#item-demand-drawer input[name='quantity']").fill_in with: "2"

    send_escape
    assert_no_selector "#item-demand-drawer[hidden]"

    find("#item-demand-drawer button", text: "Cancel").click
    assert_selector "#item-demand-drawer[hidden]", visible: :all
    assert_equal hold_button, page.active_element
  end
end
