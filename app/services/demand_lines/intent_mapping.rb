# frozen_string_literal: true

module DemandLines
  class IntentMapping
    Entry = Data.define(
      :source,
      :purpose,
      :variant_required,
      :customer_required,
      :vendor_orderable_required,
      :used_like_allowed,
      :initial_status
    )

    CUSTOMER_OR_SNAPSHOT = :customer_or_snapshot
    CUSTOMER_RECORD = :customer_record

    MAPPINGS = {
      "hold" => Entry.new(
        source: "customer_order",
        purpose: "customer_fulfillment",
        variant_required: true,
        customer_required: CUSTOMER_OR_SNAPSHOT,
        vendor_orderable_required: false,
        used_like_allowed: true,
        initial_status: "open"
      ),
      "notify" => Entry.new(
        source: "customer_order",
        purpose: "customer_fulfillment",
        variant_required: true,
        customer_required: CUSTOMER_OR_SNAPSHOT,
        vendor_orderable_required: false,
        used_like_allowed: true,
        initial_status: "open"
      ),
      "special_order" => Entry.new(
        source: "customer_order",
        purpose: "customer_fulfillment",
        variant_required: true,
        customer_required: CUSTOMER_RECORD,
        vendor_orderable_required: true,
        used_like_allowed: false,
        initial_status: "open"
      ),
      "used_wanted" => Entry.new(
        source: "used_wanted_request",
        purpose: "used_wanted",
        variant_required: true,
        customer_required: CUSTOMER_OR_SNAPSHOT,
        vendor_orderable_required: false,
        used_like_allowed: true,
        initial_status: "open"
      ),
      "manual_tbo" => Entry.new(
        source: "manual_tbo",
        purpose: "shelf_replenishment",
        variant_required: true,
        customer_required: nil,
        vendor_orderable_required: true,
        used_like_allowed: false,
        initial_status: "open"
      ),
      "buyer_replenishment" => Entry.new(
        source: "buyer_decision",
        purpose: "shelf_replenishment",
        variant_required: true,
        customer_required: nil,
        vendor_orderable_required: true,
        used_like_allowed: false,
        initial_status: "open"
      ),
      "research" => Entry.new(
        source: "customer_order",
        purpose: "customer_fulfillment",
        variant_required: false,
        customer_required: CUSTOMER_OR_SNAPSHOT,
        vendor_orderable_required: false,
        used_like_allowed: true,
        initial_status: "captured"
      )
    }.freeze

    def self.fetch(capture_intent)
      MAPPINGS[capture_intent.to_s]
    end

    def self.valid_triple?(capture_intent:, source:, purpose:)
      entry = fetch(capture_intent)
      return false if entry.blank?

      entry.source == source.to_s && entry.purpose == purpose.to_s
    end
  end
end
