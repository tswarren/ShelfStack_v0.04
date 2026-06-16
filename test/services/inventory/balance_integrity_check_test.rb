# frozen_string_literal: true

require "test_helper"

class Inventory::BalanceIntegrityCheckTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
    )
    Current.store = @store
    Inventory::PostAdjustment.call(adjustment: @adjustment, posted_by_user: @user)
  end

  test "integrity check passes when balances match ledger" do
    result = Inventory::BalanceIntegrityCheck.call(actor: @user)
    assert result.passed
  end

  test "rebuild balances fixes drift" do
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_column(:quantity_on_hand, 999)

    result = Inventory::BalanceIntegrityCheck.call(actor: @user)
    assert_not result.passed

    Inventory::RebuildBalances.call(actor: @user)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.quantity_on_hand
  end
end
