# frozen_string_literal: true

module Shelfstack
  module V0048Verify
    module_function

    V0048_SERVICE_GLOBS = [
      "app/services/sourcing/**/*.rb"
    ].freeze

    V0048_DEMAND_INTEGRATION_PATHS = [
      "app/services/demand_lines/cancel.rb",
      "app/services/demand_lines/expire.rb",
      "app/services/demand_lines/expire_due.rb"
    ].freeze

    FORBIDDEN_LEGACY_PATTERNS = [
      /CustomerRequest\.create/,
      /SpecialOrder\.create/,
      /PurchaseRequestLine\.create/,
      /PurchaseOrderLineAllocation\.create/,
      /purchase_order_line_allocations\.create/,
      /ReceiptLineAllocation\.create/,
      /receipt_line_allocations\.create/
    ].freeze

    INVENTORY_POST_PATTERN = /Inventory::Post\b/

    def tables_present?
      SourcingRun.table_exists? &&
        SourcingAttempt.table_exists? &&
        VendorResponse.table_exists?
    end

    def demand_allocations_support_vendor_backorder?
      DemandAllocation::ALLOCATION_KINDS.include?("vendor_backorder") &&
        DemandAllocation.column_names.include?("sourcing_attempt_id") &&
        DemandAllocation.column_names.include?("vendor_response_id")
    end

    def v0048_service_paths
      V0048_SERVICE_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }
                         .map { |path| path.sub("#{Rails.root}/", "") }
                         .uniq
                         .sort
    end

    def sourcing_services_avoid_inventory_post?
      v0048_service_paths.none? do |rel|
        File.read(Rails.root.join(rel)).match?(INVENTORY_POST_PATTERN)
      end
    end

    def sourcing_services_avoid_legacy_writes?
      v0048_service_paths.none? do |rel|
        content = File.read(Rails.root.join(rel))
        FORBIDDEN_LEGACY_PATTERNS.any? { |pattern| content.match?(pattern) }
      end
    end

    def used_wanted_sourcing_attempt_count_zero?
      SourcingAttempt.joins(:demand_line)
                     .where(demand_lines: { capture_intent: "used_wanted" })
                     .none?
    end

    def core_services_present?
      defined?(Sourcing::Eligibility) &&
        defined?(Sourcing::UnresolvedQuantity) &&
        defined?(Sourcing::StartRun) &&
        defined?(Sourcing::CreateAttempt) &&
        defined?(Sourcing::SubmitAttempt) &&
        defined?(Sourcing::RecordVendorResponse) &&
        defined?(Sourcing::Cascade) &&
        defined?(Sourcing::CloseRun) &&
        defined?(DemandAllocations::AllocateVendorBackorder)
    end

    def cascade_creates_pending_attempt?
      File.read(Rails.root.join("app/services/sourcing/cascade.rb")).include?('status: "pending"') ||
        !File.read(Rails.root.join("app/services/sourcing/cascade.rb")).match?(/SubmitAttempt/)
    end

    def vendor_backorder_excluded_from_cache_rebuild?
      !File.read(Rails.root.join("app/services/demand_allocations/allocate_vendor_backorder.rb")).match?(/RebuildAvailabilityCache/)
    end

    def demand_cancel_expires_sourcing?
      V0048_DEMAND_INTEGRATION_PATHS.all? do |rel|
        File.read(Rails.root.join(rel)).include?("Sourcing::CancelActiveForDemand")
      end
    end

    def report(strict: false)
      checks = {
        tables_present: tables_present?,
        demand_allocations_support_vendor_backorder: demand_allocations_support_vendor_backorder?,
        core_services_present: core_services_present?,
        v0048_services_avoid_inventory_post: sourcing_services_avoid_inventory_post?,
        v0048_services_avoid_legacy_writes: sourcing_services_avoid_legacy_writes?,
        used_wanted_sourcing_attempt_count_zero: used_wanted_sourcing_attempt_count_zero?,
        vendor_backorder_excluded_from_cache_rebuild: vendor_backorder_excluded_from_cache_rebuild?,
        demand_cancel_expires_sourcing: demand_cancel_expires_sourcing?,
        cascade_creates_pending_attempt: cascade_creates_pending_attempt?
      }

      failures = checks.reject { |_key, ok| ok }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: checks,
        failures: failures,
        summary: "v0.04-8 sourcing verification: #{status} (#{failures.size} failures)"
      }
    end
  end
end
