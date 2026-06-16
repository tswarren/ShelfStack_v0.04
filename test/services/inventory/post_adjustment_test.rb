# frozen_string_literal: true

require "test_helper"

class Inventory::PostAdjustmentTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @variant_one = create_product_variant!(inventory_behavior: "standard_physical")
    @variant_two = create_product_variant!(
      sub_department: @variant_one.sub_department,
      inventory_behavior: "standard_physical"
    )
    Current.store = @store
  end

  test "multi line adjustment updates multiple balances" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [
        { product_variant: @variant_one, quantity_delta: 3, line_number: 1 },
        { product_variant: @variant_two, quantity_delta: 7, line_number: 2 }
      ]
    )

    posting = Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)

    assert_equal 2, posting.inventory_ledger_entries.count
    assert_equal 3, InventoryBalance.find_by!(store: @store, product_variant: @variant_one).quantity_on_hand
    assert_equal 7, InventoryBalance.find_by!(store: @store, product_variant: @variant_two).quantity_on_hand
    assert AuditEvent.exists?(event_name: "inventory_adjustment.posted", auditable: adjustment)
    assert AuditEvent.exists?(event_name: "inventory_posting.created", auditable: posting)
  end

  test "balance correction uses correction movement type" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      attrs: { adjustment_type: "balance_correction" },
      lines: [ { product_variant: @variant_one, quantity_delta: 2, line_number: 1 } ]
    )

    posting = Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)
    entry = posting.inventory_ledger_entries.first

    assert_equal "balance_correction", posting.posting_type
    assert_equal "correction", entry.movement_type
  end

  test "post rejects zero quantity lines" do
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: @variant_one, quantity_delta: 0, line_number: 1 } ]
    )

    assert_raises(Inventory::PostAdjustment::PostingError) do
      Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)
    end
  end
end
