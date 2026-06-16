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
end
