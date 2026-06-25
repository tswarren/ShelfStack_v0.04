# frozen_string_literal: true

require "test_helper"

class Inventory::RebuildBalancesTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 6, line_number: 1 } ]
      ),
      user: @user
    )
  end

  test "rebuild corrects mismatched cached balance" do
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_column(:quantity_on_hand, 99)

    Inventory::RebuildBalances.call(actor: @user)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 6, balance.quantity_on_hand
    assert AuditEvent.exists?(event_name: "inventory.balance_rebuild")
  end

  test "rebuild preserves signed inventory value after sale" do
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5, unit_cost_cents: 800)

    workstation = create_workstation!(store: @store)
    grant_all_phase6_permissions!(@user, store: @store)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    register_session = open_register_session!(store: @store, workstation: workstation, user: @user)
    transaction = create_pos_transaction!(
      store: @store,
      workstation: workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 } ]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: register_session)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    expected_cost_value = balance.inventory_cost_value_cents
    assert_operator expected_cost_value, :>, 0

    balance.update_column(:inventory_cost_value_cents, 99_999)

    Inventory::RebuildBalances.call(actor: @user)

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 10, balance.quantity_on_hand
    assert_equal expected_cost_value, balance.inventory_cost_value_cents
  end
end
