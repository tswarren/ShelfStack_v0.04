# frozen_string_literal: true

module Shelfstack
  module V0047Verify
    module_function

    V0047_SERVICE_GLOB = "app/services/demand_allocations/**/*.rb"
    ALLOCATION_DEMAND_LINE_GLOB = "app/services/demand_lines/{recalculate_allocation_status,expire_due}.rb"

    FORBIDDEN_LEGACY_PATTERNS = [
      /InventoryReservation\.create/,
      /inventory_reservations\.create/,
      /PurchaseOrderLineAllocation\.create/,
      /purchase_order_line_allocations\.create/,
      /ReceiptLineAllocation\.create/,
      /receipt_line_allocations\.create/
    ].freeze

    INVENTORY_POST_PATTERN = /Inventory::Post\b/

    def tables_present?
      DemandAllocation.table_exists?
    end

    def allocation_services_avoid_inventory_post?
      allocation_service_paths.none? do |rel|
        File.read(Rails.root.join(rel)).match?(INVENTORY_POST_PATTERN)
      end
    end

    def allocation_services_avoid_legacy_writes?
      allocation_service_paths.none? do |rel|
        content = File.read(Rails.root.join(rel))
        FORBIDDEN_LEGACY_PATTERNS.any? { |pattern| content.match?(pattern) }
      end
    end

    def expire_due_service_present?
      defined?(DemandLines::ExpireDue) &&
        File.exist?(Rails.root.join("app/services/demand_lines/expire_due.rb"))
    end

    def cache_consistency_valid?(sample_limit: 25)
      InventoryBalance.limit(sample_limit).find_each.all? do |balance|
        legacy = legacy_on_hand_reserved(balance)
        v0047 = DemandAllocations::AllocationQuantities.active_on_hand_for(
          store: balance.store,
          variant: balance.product_variant
        )
        expected_reserved = legacy + v0047
        balance.quantity_reserved == expected_reserved &&
          balance.quantity_available == balance.quantity_on_hand - balance.quantity_reserved
      end
    end

    def override_overages_valid?
      DemandAllocation.active_allocations.on_hand_kind.find_each.group_by do |allocation|
        [ allocation.store_id, allocation.product_variant_id ]
      end.all? do |(store_id, variant_id), allocations|
        store = Store.find(store_id)
        variant = ProductVariant.find(variant_id)
        balance = InventoryBalance.find_by(store: store, product_variant: variant)
        on_hand = balance&.quantity_on_hand.to_i
        allocated = allocations.sum(&:quantity_allocated)
        next true if allocated <= on_hand

        excess = allocated - on_hand
        override_qty = allocations.select(&:override_availability?).sum(&:quantity_allocated)
        override_qty >= excess &&
          allocations.select(&:override_availability?).all? do |row|
            row.override_authorized_by_user_id.present? &&
              row.override_authorized_at.present? &&
              row.override_reason.present?
          end
      end
    end

    def inbound_within_open_qty?
      DemandAllocation.active_allocations.inbound_kind.find_each.all? do |allocation|
        po_line = allocation.purchase_order_line
        next false if po_line.blank?

        open_qty = po_line.purchase_order.open_quantity_for_line(po_line)
        claimed = DemandAllocation.active_allocations.inbound_kind
                                  .where(purchase_order_line: po_line)
                                  .sum(:quantity_allocated)
        claimed <= open_qty
      end
    end

    def used_wanted_inbound_count_zero?
      DemandAllocation.inbound_kind
                      .joins(:demand_line)
                      .where(demand_lines: { capture_intent: "used_wanted" })
                      .none?
    end

    def terminal_allocations_valid?(sample_limit: 50)
      DemandAllocation.where(status: DemandAllocation::TERMINAL_STATUSES).limit(sample_limit).all? do |row|
        row.valid?
      end
    end

    def allocation_service_paths
      Dir.glob(Rails.root.join(V0047_SERVICE_GLOB)).map { |path| path.sub("#{Rails.root}/", "") }.sort
    end

    def legacy_on_hand_reserved(balance)
      InventoryReservation.active_on_hand
                          .where(store: balance.store, product_variant: balance.product_variant)
                          .sum("quantity_reserved - quantity_fulfilled - quantity_released")
    end

    def report(strict: false)
      checks = {
        tables_present: tables_present?,
        allocation_services_avoid_inventory_post: allocation_services_avoid_inventory_post?,
        allocation_services_avoid_legacy_writes: allocation_services_avoid_legacy_writes?,
        expire_due_service_present: expire_due_service_present?,
        cache_consistency_valid: cache_consistency_valid?,
        override_overages_valid: override_overages_valid?,
        inbound_within_open_qty: inbound_within_open_qty?,
        used_wanted_inbound_count_zero: used_wanted_inbound_count_zero?,
        terminal_allocations_valid: terminal_allocations_valid?
      }

      failures = checks.reject { |_key, ok| ok }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: checks,
        failures: failures,
        summary: "v0.04-7 allocations verification: #{status} (#{failures.size} failures)"
      }
    end
  end
end
