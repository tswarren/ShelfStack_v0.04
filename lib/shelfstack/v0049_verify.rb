# frozen_string_literal: true

module Shelfstack
  module V0049Verify
    module_function

    V0049_SERVICE_GLOBS = [
      "app/services/purchasing/po_line_quantity_summary.rb",
      "app/services/purchasing/sync_po_line_vendor_quantities_from_sourcing.rb",
      "app/services/purchasing/receipt_posting_guards.rb",
      "app/services/purchasing/inbound_availability_snapshot.rb",
      "app/services/demand_allocations/convert_inbound_from_receipt.rb",
      "app/services/demand_allocations/release_uncovered_inbound.rb"
    ].freeze

    FORBIDDEN_LEGACY_PATTERNS = [
      /PurchaseOrderLineAllocation\.create/,
      /purchase_order_line_allocations\.create/,
      /ReceiptLineAllocation\.create/,
      /receipt_line_allocations\.create/
    ].freeze

    INVENTORY_POST_PATTERN = /Inventory::Post\b/

    def po_line_vendor_columns_present?
      PurchaseOrderLine.column_names.include?("vendor_quantity_state") &&
        PurchaseOrderLine.column_names.include?("quantity_confirmed_by_vendor") &&
        PurchaseOrderLine.column_names.include?("quantity_closed_short") &&
        PurchaseOrderLine.column_names.include?("vendor_quantities_recorded_at")
    end

    def demand_allocation_conversion_columns_present?
      DemandAllocation.column_names.include?("converted_from_allocation_id") &&
        DemandAllocation.column_names.include?("conversion_receipt_line_id") &&
        DemandAllocation.column_names.include?("conversion_purchase_order_line_id") &&
        DemandAllocation::STATUSES.include?("converted")
    end

    def conversion_services_present?
      defined?(Purchasing::PoLineQuantitySummary) &&
        defined?(Purchasing::SyncPoLineVendorQuantitiesFromSourcing) &&
        defined?(DemandAllocations::ConvertInboundFromReceipt) &&
        defined?(DemandAllocations::ReleaseUncoveredInbound) &&
        defined?(Purchasing::InboundAvailabilitySnapshot)
    end

    def post_receipt_calls_conversion?
      content = File.read(Rails.root.join("app/services/purchasing/post_receipt.rb"))
      content.include?("ConvertInboundFromReceipt") &&
        content.include?("ReceiptPostingGuards.assert_no_mixed_claims!")
    end

    def converted_allocations_valid?(sample_limit: 50)
      DemandAllocation.where(status: "converted").limit(sample_limit).all?(&:valid?)
    end

    def converted_on_hand_rows_have_fks?(sample_limit: 50)
      DemandAllocation.on_hand_kind
                      .where.not(converted_from_allocation_id: nil)
                      .limit(sample_limit)
                      .all? do |row|
        row.converted_from_allocation_id.present? &&
          row.conversion_receipt_line_id.present?
      end
    end

    def receipt_line_converted_totals_within_accepted?
      ReceiptLine.joins(:receipt).where(receipts: { status: "posted" }).find_each.all? do |line|
        converted_total = DemandAllocation.on_hand_kind
                                          .where(conversion_receipt_line_id: line.id)
                                          .sum(:quantity_allocated)
        converted_total <= line.quantity_accepted.to_i
      end
    end

    def core_services_present?
      conversion_services_present?
    end

    def v0049_service_paths
      V0049_SERVICE_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }
                         .map { |path| path.sub("#{Rails.root}/", "") }
                         .uniq
                         .sort
    end

    def v0049_services_avoid_legacy_writes?
      v0049_service_paths.all? do |rel|
        next true unless File.exist?(Rails.root.join(rel))

        content = File.read(Rails.root.join(rel))
        FORBIDDEN_LEGACY_PATTERNS.none? { |pattern| content.match?(pattern) }
      end
    end

    def v0049_services_avoid_inventory_post?
      v0049_service_paths.all? do |rel|
        next true unless File.exist?(Rails.root.join(rel))

        !File.read(Rails.root.join(rel)).match?(INVENTORY_POST_PATTERN)
      end
    end

    def unconfirmed_fallback_fixture_valid?
      line = PurchaseOrderLine.where(vendor_quantities_recorded_at: nil).first
      return true if line.blank?

      summary = Purchasing::PoLineQuantitySummary.for(line)
      summary.effective_inbound_supply == [ line.quantity_ordered - line.quantity_received - line.quantity_closed_short, 0 ].max
    end

    def recorded_zero_no_ordered_fallback?
      line = PurchaseOrderLine.where.not(vendor_quantities_recorded_at: nil)
                              .where(quantity_confirmed_by_vendor: 0)
                              .first
      return true if line.blank?

      Purchasing::PoLineQuantitySummary.for(line).effective_inbound_supply.zero?
    end

    def mixed_legacy_v0047_claims_on_same_po_line?
      PurchaseOrderLine.find_each.any? do |po_line|
        legacy = po_line.purchase_order_line_allocations
                        .where(status: DemandAllocations::InboundAvailability::LEGACY_OPEN_ALLOCATION_STATUSES)
                        .exists?
        v0047 = DemandAllocation.active_allocations.inbound_kind.where(purchase_order_line: po_line).exists?
        legacy && v0047
      end
    end

    def inbound_within_open_supply?
      po_line_ids = DemandAllocation.active_allocations.inbound_kind.distinct.pluck(:purchase_order_line_id)
      po_line_ids.all? do |po_line_id|
        po_line = PurchaseOrderLine.find_by(id: po_line_id)
        next true if po_line.blank?

        supply = Purchasing::PoLineQuantitySummary.for(po_line).open_supply_before_allocation_claims
        legacy_claimed = po_line.purchase_order_line_allocations
                                .where(status: DemandAllocations::InboundAvailability::LEGACY_OPEN_ALLOCATION_STATUSES)
                                .sum(:quantity_allocated)
        v0047_claimed = DemandAllocation.active_allocations.inbound_kind
                                        .where(purchase_order_line: po_line)
                                        .sum(:quantity_allocated)
        v0047_claimed <= supply - legacy_claimed
      end
    end

    def report(strict: false)
      checks = {
        po_line_vendor_columns_present: po_line_vendor_columns_present?,
        demand_allocation_conversion_columns_present: demand_allocation_conversion_columns_present?,
        core_services_present: core_services_present?,
        post_receipt_calls_conversion: post_receipt_calls_conversion?,
        v0049_services_avoid_legacy_writes: v0049_services_avoid_legacy_writes?,
        v0049_services_avoid_inventory_post: v0049_services_avoid_inventory_post?,
        unconfirmed_fallback_fixture_valid: unconfirmed_fallback_fixture_valid?,
        recorded_zero_no_ordered_fallback: recorded_zero_no_ordered_fallback?,
        inbound_within_open_supply: inbound_within_open_supply?,
        mixed_legacy_v0047_claims_absent: !mixed_legacy_v0047_claims_on_same_po_line?,
        converted_allocations_valid: converted_allocations_valid?,
        converted_on_hand_rows_have_fks: converted_on_hand_rows_have_fks?,
        receipt_line_converted_totals_within_accepted: receipt_line_converted_totals_within_accepted?
      }

      failures = checks.reject { |_key, ok| ok }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: checks,
        failures: failures,
        summary: "v0.04-9 PO/receiving verification: #{status} (#{failures.size} failures)"
      }
    end
  end
end
