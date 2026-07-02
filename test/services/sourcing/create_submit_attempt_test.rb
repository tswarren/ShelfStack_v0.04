# frozen_string_literal: true

require "test_helper"

class SourcingCreateSubmitAttemptTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase5TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant, vendor_item_number: "ABC-123")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user)
    @ledger_before = InventoryLedgerEntry.count
  end

  test "create attempt pending with audit" do
    attempt = Sourcing::CreateAttempt.call!(
      sourcing_run: @run,
      actor: @user,
      vendor: @vendor,
      quantity: 2
    )

    assert_equal "pending", attempt.status
    assert_equal 1, attempt.sequence_number
    assert AuditEvent.exists?(event_name: "sourcing_attempt.created", auditable: attempt)
  end

  test "submit attempt snapshots vendor fields and does not post inventory" do
    attempt = Sourcing::CreateAttempt.call!(
      sourcing_run: @run,
      actor: @user,
      vendor: @vendor,
      quantity: 2
    )

    submitted = Sourcing::SubmitAttempt.call!(sourcing_attempt: attempt, actor: @user)

    assert_equal "submitted", submitted.status
    assert_equal "ABC-123", submitted.vendor_item_number_snapshot
    assert submitted.vendor_name_snapshot.present?
    assert submitted.submitted_at.present?
    assert AuditEvent.exists?(event_name: "sourcing_attempt.submitted", auditable: submitted)
    assert_equal @ledger_before, InventoryLedgerEntry.count
  end

  test "create attempt rejects quantity above run unresolved" do
    assert_raises(Sourcing::CreateAttempt::CreateAttemptError) do
      Sourcing::CreateAttempt.call!(
        sourcing_run: @run,
        actor: @user,
        vendor: @vendor,
        quantity: 3
      )
    end
  end

  test "manual override requires reason and records audit" do
    other_vendor = create_vendor!(name: "Override Vendor")
    attempt = Sourcing::CreateAttempt.call!(
      sourcing_run: @run,
      actor: @user,
      vendor: other_vendor,
      quantity: 1,
      manual_vendor_override: true,
      override_reason: "Publisher direct required"
    )

    assert attempt.manual_vendor_override?
    assert AuditEvent.exists?(event_name: "sourcing.manual_vendor_override", auditable: attempt)
  end

  test "create attempt rejects wrong-variant purchase order line" do
    other_variant = create_product_variant!(inventory_behavior: "standard_physical")
    other_vendor = create_vendor_for_variant!(other_variant)
    po = create_purchase_order!(
      store: @store,
      vendor: other_vendor,
      lines: [ create_purchase_order_line_attrs(variant: other_variant, vendor: other_vendor, quantity_ordered: 5) ]
    )
    po.update!(status: "submitted")
    po_line = po.purchase_order_lines.first

    assert_raises(Sourcing::ValidatePoLineLink::ValidationError) do
      Sourcing::CreateAttempt.call!(
        sourcing_run: @run,
        actor: @user,
        vendor: @vendor,
        quantity: 1,
        purchase_order_line: po_line
      )
    end
  end

  test "create attempt rejects ineligible purchase order line" do
    po = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
    po_line = po.purchase_order_lines.first

    assert_raises(Sourcing::ValidatePoLineLink::ValidationError) do
      Sourcing::CreateAttempt.call!(
        sourcing_run: @run,
        actor: @user,
        vendor: @vendor,
        quantity: 1,
        purchase_order_line: po_line
      )
    end
  end
end
