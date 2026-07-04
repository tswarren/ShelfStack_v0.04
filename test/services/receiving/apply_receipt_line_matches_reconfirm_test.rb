# frozen_string_literal: true

require "test_helper"

class ReceivingApplyReceiptLineMatchesReconfirmTest < ActiveSupport::TestCase
  include Phase5TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 5,
          quantity_received: 0
        )
      ]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @purchase_order, submitted_by_user: @user)
    @po_line = @purchase_order.purchase_order_lines.first
    @receipt = Receiving::CreateVendorShipmentReceipt.call!(
      store: @store,
      vendor: @vendor,
      attrs: {}
    )
    @receipt_line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 3,
      quantity_accepted: 3,
      quantity_rejected: 0,
      unit_cost_cents: 1000
    )
    @match_attrs = {
      receipt_line_id: @receipt_line.id,
      purchase_order_line_id: @po_line.id,
      quantity_matched: 3,
      match_source: "auto"
    }
  end

  test "reconfirms released match with same idempotency key" do
    match = Receiving::ApplyReceiptLineMatches.call!(
      receipt: @receipt,
      actor: @user,
      matches: [ @match_attrs ]
    ).first

    match.update!(
      match_status: "released",
      released_at: Time.current,
      released_by_user: @user,
      release_reason: "Retry"
    )

    assert_no_difference -> { ReceiptLineMatch.count } do
      Receiving::ApplyReceiptLineMatches.call!(
        receipt: @receipt.reload,
        actor: @user,
        matches: [ @match_attrs.merge(quantity_matched: 2, match_source: "manual") ]
      )
    end

    match.reload
    assert_equal "confirmed", match.match_status
    assert_equal 2, match.quantity_matched
    assert_nil match.released_at
    assert AuditEvent.exists?(auditable: match, event_name: "receipt_line_match.reconfirmed")
  end

  test "reapplying confirmed match with same idempotency key is idempotent" do
    Receiving::ApplyReceiptLineMatches.call!(
      receipt: @receipt,
      actor: @user,
      matches: [ @match_attrs ]
    )

    assert_no_difference -> { ReceiptLineMatch.count } do
      applied = Receiving::ApplyReceiptLineMatches.call!(
        receipt: @receipt.reload,
        actor: @user,
        matches: [ @match_attrs ]
      )
      assert_equal 1, applied.size
      assert applied.first.confirmed?
    end
  end

  test "rejects PO line from another vendor" do
    other_vendor = create_vendor!(name: "Other Vendor")
    other_po = create_purchase_order!(
      store: @store,
      vendor: other_vendor,
      attrs: { status: "submitted", submitted_at: Time.current },
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: other_vendor,
          quantity_ordered: 3,
          quantity_received: 0
        )
      ]
    )
    other_po_line = other_po.purchase_order_lines.first

    error = assert_raises(Receiving::ApplyReceiptLineMatches::ApplyError) do
      Receiving::ApplyReceiptLineMatches.call!(
        receipt: @receipt,
        actor: @user,
        matches: [
          @match_attrs.merge(purchase_order_line_id: other_po_line.id)
        ]
      )
    end

    assert_match(/same store and vendor/i, error.message)
  end

  test "rejects custom idempotency key reused for a different receipt match" do
    Receiving::ApplyReceiptLineMatches.call!(
      receipt: @receipt,
      actor: @user,
      matches: [ @match_attrs.merge(idempotency_key: "custom-key-1") ]
    )

    other_po_line = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "submitted", submitted_at: Time.current },
      lines: [
        create_purchase_order_line_attrs(
          variant: @variant,
          vendor: @vendor,
          quantity_ordered: 1,
          quantity_received: 0
        )
      ]
    ).purchase_order_lines.first

    error = assert_raises(Receiving::ApplyReceiptLineMatches::ApplyError) do
      Receiving::ApplyReceiptLineMatches.call!(
        receipt: @receipt.reload,
        actor: @user,
        matches: [
          {
            receipt_line_id: @receipt_line.id,
            purchase_order_line_id: other_po_line.id,
            quantity_matched: 1,
            idempotency_key: "custom-key-1"
          }
        ]
      )
    end

    assert_match(/different receipt match/i, error.message)
  end
end
