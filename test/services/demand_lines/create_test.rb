# frozen_string_literal: true

require "test_helper"

class DemandLinesCreateTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper

  setup do
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @customer = create_customer!(display_name: "Create Customer")
    @ledger_before = InventoryLedgerEntry.count
    @balance_before = InventoryBalance.find_by(store: @store, product_variant: @variant)&.quantity_on_hand
  end

  test "creates matched demand with demand number and audit" do
    line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "notify",
      variant: @variant,
      customer: @customer,
      quantity: 2
    )

    assert_match(/\A#{@store.store_number}-D\d{6}\z/, line.demand_number)
    assert_equal "open", line.status
    assert_equal "customer_order", line.source
    assert_equal "customer_fulfillment", line.purpose
    assert_equal 2, line.quantity_requested
    assert AuditEvent.exists?(event_name: "demand_line.created", auditable: line)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "create does not write legacy demand rows" do
    assert_no_difference [ -> { CustomerRequest.count }, -> { SpecialOrder.count }, -> { PurchaseRequestLine.count } ] do
      DemandLines::Create.call!(
        store: @store,
        actor: @user,
        capture_intent: "special_order",
        variant: @variant,
        customer: @customer
      )
    end
  end

  test "research creates captured provisional demand" do
    line = DemandLines::CreateFromProvisional.call!(
      store: @store,
      actor: @user,
      customer_name_snapshot: "Guest",
      provisional_title: "Unknown title"
    )

    assert_equal "captured", line.status
    assert_equal "research", line.capture_intent
    assert_nil line.product_variant_id
    assert_equal "Unknown title", line.provisional_title
  end
end
