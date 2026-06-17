# frozen_string_literal: true

require "test_helper"

class Purchasing::PostReceiptTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
  end

  test "posts only accepted quantity and updates balance" do
    receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      lines: [
        {
          product_variant: @variant,
          line_number: 1,
          quantity_expected: 5,
          quantity_received: 5,
          quantity_accepted: 4,
          quantity_rejected: 1,
          unit_cost_cents: 800
        }
      ]
    )

    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: @user)

    assert_equal "posted", receipt.reload.status
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 4, balance.quantity_on_hand
    assert_equal 800, balance.moving_average_unit_cost_cents
    assert AuditEvent.exists?(event_name: "receipt.posted", auditable: receipt)
  end
end
