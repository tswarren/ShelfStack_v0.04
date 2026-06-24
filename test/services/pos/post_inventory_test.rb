# frozen_string_literal: true

require "test_helper"

class Pos::PostInventoryTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "sale posts negative quantity delta and decrements on hand" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 2, unit_price_cents: 1000, extended_price_cents: 2000 } ]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @register_session)

    entry = transaction.reload.inventory_posting.inventory_ledger_entries.sole
    assert_equal "sold", entry.movement_type
    assert_equal(-2, entry.quantity_delta)
    assert_equal 3, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
  end

  test "return to stock posts positive quantity delta and increments on hand" do
    sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    complete_pos_sale!(transaction: sale, user: @user, register_session: @register_session)
    assert_equal 4, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand

    return_txn = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: 1000,
        extended_price_cents: -1000,
        return_disposition: "return_to_stock"
      } ]
    )
    grant_no_receipt_return_authorization!(return_txn)
    complete_pos_sale!(transaction: return_txn, user: @user, register_session: @register_session)

    entries = return_txn.reload.inventory_posting.inventory_ledger_entries
    assert_equal 1, entries.size
    assert_equal "customer_return", entries.first.movement_type
    assert_equal 1, entries.first.quantity_delta
    assert_equal 5, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
  end

  test "eligible_line? posts when snapshot is standard_physical" do
    line = build_pos_line(inventory_behavior_snapshot: "standard_physical")

    assert Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? does not post when snapshot is non_inventory" do
    line = build_pos_line(inventory_behavior_snapshot: "non_inventory")

    assert_not Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? does not post when snapshot is digital_asset" do
    line = build_pos_line(inventory_behavior_snapshot: "digital_asset")

    assert_not Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? posts when snapshot blank and variant is standard_physical" do
    @variant.update!(inventory_behavior: "standard_physical")
    line = build_pos_line(inventory_behavior_snapshot: nil)

    assert Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? does not post when snapshot blank and variant is non_inventory" do
    @variant.update!(inventory_behavior: "non_inventory")
    line = build_pos_line(inventory_behavior_snapshot: nil)

    assert_not Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? posts return-to-stock when snapshot is inventory" do
    line = build_pos_line(
      quantity: -1,
      return_disposition: "return_to_stock",
      inventory_behavior_snapshot: "standard_physical"
    )

    assert Pos::PostInventory.eligible_line?(line)
  end

  test "eligible_line? does not post return without return_to_stock disposition" do
    line = build_pos_line(
      quantity: -1,
      return_disposition: "damaged",
      inventory_behavior_snapshot: "standard_physical"
    )

    assert_not Pos::PostInventory.eligible_line?(line)
  end

  test "non_inventory variant completes sale without inventory posting" do
    @variant.update!(inventory_behavior: "non_inventory")

    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000
      } ]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @register_session)

    assert_nil transaction.reload.inventory_posting
  end

  private

  def build_pos_line(**attrs)
    defaults = {
      product_variant: @variant,
      product_variant_id: @variant.id,
      quantity: 1,
      line_type: "variant"
    }
    PosTransactionLine.new(defaults.merge(attrs))
  end

  def grant_no_receipt_return_authorization!(transaction)
    manager = create_user!(username: "manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: @store)
    Pos::AuthorizationRequest.grant!(
      authorization_type: "no_receipt_return",
      requested_by: @user,
      manager_username: manager.username,
      manager_pin: "4321",
      store: @store,
      pos_transaction: transaction
    )
  end
end
