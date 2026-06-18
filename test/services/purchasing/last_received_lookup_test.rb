# frozen_string_literal: true

require "test_helper"

class Purchasing::LastReceivedLookupTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!
    Current.store = @store
  end

  test "returns most recent posted receipt line with accepted quantity" do
    older_receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "posted", posted_at: 2.days.ago },
      lines: [
        {
          product_variant: @variant,
          quantity_expected: 2,
          quantity_received: 2,
          quantity_accepted: 2,
          unit_cost_cents: 800
        }
      ]
    )
    newer_receipt = create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "posted", posted_at: 1.day.ago },
      lines: [
        {
          product_variant: @variant,
          quantity_expected: 3,
          quantity_received: 3,
          quantity_accepted: 3,
          unit_cost_cents: 900
        }
      ]
    )

    result = Purchasing::LastReceivedLookup.for_variant(store: @store, variant: @variant)

    assert_equal newer_receipt.posted_at.to_i, result.received_at.to_i
    assert_equal 3, result.quantity_accepted
    assert_equal 900, result.unit_cost_cents
    assert_equal newer_receipt, result.receipt
    assert_equal @vendor, result.vendor
  end

  test "ignores receipt lines with zero accepted quantity" do
    create_receipt!(
      store: @store,
      vendor: @vendor,
      attrs: { status: "posted", posted_at: 1.day.ago },
      lines: [
        {
          product_variant: @variant,
          quantity_expected: 2,
          quantity_received: 2,
          quantity_accepted: 0,
          quantity_rejected: 2,
          unit_cost_cents: 800
        }
      ]
    )

    assert_nil Purchasing::LastReceivedLookup.for_variant(store: @store, variant: @variant)
  end
end
