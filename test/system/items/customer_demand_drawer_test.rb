# frozen_string_literal: true

require "application_system_test_case"

class ItemsCustomerDemandDrawerSystemTest < ApplicationSystemTestCase
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.catalog_items.view", store: @store)
    grant_permission!(@user, "demand.access", store: @store)
    grant_permission!(@user, "demand.create", store: @store)
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

  def open_variant_ops_drawer!
    find("button", text: "Details", match: :first).click
    assert_no_selector "#item-variant-ops-drawer[hidden]", wait: 10
  end

  test "demand actions open from variant operations drawer and restore focus on close" do
    visit_item_operations!

    assert_selector "#item-variant-ops-drawer", visible: :hidden
    details_button = find("button", text: "Details", match: :first)
    details_button.click
    assert_no_selector "#item-variant-ops-drawer[hidden]"

    hold_button = find("#item-variant-ops-drawer button", text: "Record hold request")
    hold_button.click
    assert_selector "#item-variant-ops-drawer [data-item-variant-ops-drawer-target='demandSection']:not([hidden])"

    find("#item-variant-ops-drawer .ss-drawer-close").click
    assert_selector "#item-variant-ops-drawer[hidden]", visible: :all
    assert_equal details_button, page.active_element
  end

  test "variant operations drawer closes on escape when form is clean" do
    visit_item_operations!

    details_button = find("button", text: "Details", match: :first)
    open_variant_ops_drawer!
    hold_button = find("#item-variant-ops-drawer button", text: "Record hold request")
    hold_button.click

    send_escape
    assert_selector "#item-variant-ops-drawer[hidden]", visible: :all
    assert_equal details_button, page.active_element
  end

  test "demand form stays open on escape when dirty" do
    visit_item_operations!
    open_variant_ops_drawer!
    find("#item-variant-ops-drawer button", text: "Record hold request").click
    find("#item-variant-ops-drawer input[name='quantity']").fill_in with: "2"

    send_escape
    assert_no_selector "#item-variant-ops-drawer[hidden]"
  end

  test "demand form resets after cancel" do
    visit_item_operations!
    open_variant_ops_drawer!
    find("#item-variant-ops-drawer button", text: "Record hold request").click
    find("#item-variant-ops-drawer input[name='quantity']").fill_in with: "2"
    find("#item-variant-ops-drawer button", text: "Cancel").click
    assert_selector "#item-variant-ops-drawer[hidden]", visible: :all

    find("button", text: "Details", match: :first).click
    assert_no_selector "#item-variant-ops-drawer[hidden]"
    find("#item-variant-ops-drawer button", text: "Record hold request").click
    assert_equal "1", find("#item-variant-ops-drawer input[name='quantity']").value
  end
end
