# frozen_string_literal: true

require "test_helper"

class Inventory::PostTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: 5, line_number: 1 } ]
    )
    Current.store = @store
  end

  test "posting creates posting ledger and balance atomically" do
    posting = Inventory::PostAdjustment.call(adjustment: @adjustment, posted_by_user: @user)

    assert_equal "posted", @adjustment.reload.status
    assert_equal 1, posting.inventory_ledger_entries.count

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 5, balance.quantity_on_hand
    assert_equal 5, balance.quantity_available
    assert_equal 5, InventoryLedgerEntry.where(store: @store, product_variant: @variant).sum(:quantity_delta)
  end

  test "posting rejects ineligible variant" do
    @variant.update!(inventory_behavior: "non_inventory")
    assert_raises(Inventory::Eligibility::IneligibleVariantError) do
      Inventory::PostAdjustment.call(adjustment: @adjustment, posted_by_user: @user)
    end
  end

  test "posting is idempotent per adjustment" do
    first = Inventory::PostAdjustment.call(adjustment: @adjustment, posted_by_user: @user)
    second = Inventory::PostAdjustment.call(adjustment: @adjustment.reload, posted_by_user: @user)
    assert_equal first.id, second.id
    assert_equal 1, InventoryPosting.where(source: @adjustment).count
  end

  test "negative on hand is allowed" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant, quantity_delta: -10, line_number: 1 } ]
    )
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal(-10, balance.quantity_on_hand)
  end
end
