# frozen_string_literal: true

module Shelfstack
  module V00410Verify
    module_function

    LEGACY_TABLES = %w[
      customer_requests
      customer_request_lines
      special_orders
      purchase_requests
      purchase_request_lines
      inventory_reservations
      purchase_order_line_allocations
      receipt_line_allocations
    ].freeze

    LEGACY_ROUTE_PATTERNS = [
      /resources\s+:customer_requests\b/,
      /resources\s+:purchase_requests\b/,
      /\bfrom_tbo\b/,
      /customer_requests#show/
    ].freeze

    LEGACY_STAFF_PERMISSION_PREFIXES = %w[
      customer_requests.
      special_orders.
      purchase_requests.
      inventory_reservations.
    ].freeze

    def phase
      ENV.fetch("V00410_PHASE", "g1").downcase
    end

    def g2?
      phase == "g2"
    end

    def pos_demand_allocation_column_present?
      PosTransactionLine.column_names.include?("demand_allocation_id")
    end

    def demand_pickup_services_present?
      defined?(Pos::DemandPickupLookup) &&
        defined?(Pos::AddDemandAllocationLine) &&
        defined?(Pos::CompleteDemandAllocationFulfillment)
    end

    def post_receipt_skips_legacy_allocator?
      content = File.read(Rails.root.join("app/services/purchasing/post_receipt.rb"))
      !content.include?("AllocateCustomerDemandFromReceipt")
    end

    def complete_transaction_uses_demand_fulfillment?
      content = File.read(Rails.root.join("app/services/pos/complete_transaction.rb"))
      content.include?("CompleteDemandAllocationFulfillment")
    end

    def pickup_lookup_uses_demand?
      content = File.read(Rails.root.join("app/controllers/pos/pickup_lookups_controller.rb"))
      content.include?("DemandPickupLookup")
    end

    def legacy_tables_absent?
      LEGACY_TABLES.none? { |table| ActiveRecord::Base.connection.table_exists?(table) }
    end

    def legacy_routes_absent?
      routes_content = File.read(Rails.root.join("config/routes.rb"))
      LEGACY_ROUTE_PATTERNS.none? { |pattern| routes_content.match?(pattern) }
    end

    def legacy_models_absent?
      %w[CustomerRequest CustomerRequestLine SpecialOrder PurchaseRequest InventoryReservation].none? do |name|
        Object.const_defined?(name)
      end
    end

    def inbound_availability_without_legacy_claims?
      content = File.read(Rails.root.join("app/services/demand_allocations/inbound_availability.rb"))
      !content.include?("purchase_order_line_allocations")
    end

    def demand_queue_scope_present?
      defined?(DemandLines::QueueScope)
    end

    def demand_queue_report_present?
      defined?(Reports::DemandQueue::Query)
    end

    def legacy_staff_permissions_absent?
      app_root = Rails.root.join("app")
      paths = Dir.glob(app_root.join("**/*.{rb,erb}"))
      paths.none? do |path|
        content = File.read(path)
        LEGACY_STAFF_PERMISSION_PREFIXES.any? do |prefix|
          content.include?("\"#{prefix}") || content.include?("'#{prefix}")
        end
      end
    end

    def g1_checks
      {
        pos_demand_allocation_column_present: pos_demand_allocation_column_present?,
        demand_pickup_services_present: demand_pickup_services_present?,
        post_receipt_skips_legacy_allocator: post_receipt_skips_legacy_allocator?,
        complete_transaction_uses_demand_fulfillment: complete_transaction_uses_demand_fulfillment?,
        pickup_lookup_uses_demand: pickup_lookup_uses_demand?,
        demand_queue_scope_present: demand_queue_scope_present?,
        demand_queue_report_present: demand_queue_report_present?
      }
    end

    def g2_checks
      g1_checks.merge(
        legacy_tables_absent: legacy_tables_absent?,
        legacy_routes_absent: legacy_routes_absent?,
        legacy_models_absent: legacy_models_absent?,
        inbound_availability_without_legacy_claims: inbound_availability_without_legacy_claims?,
        legacy_staff_permissions_absent: legacy_staff_permissions_absent?
      )
    end

    def report(strict: false)
      checks = g2? ? g2_checks : g1_checks
      failures = checks.reject { |_key, ok| ok }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        phase: phase,
        checks: checks,
        failures: failures,
        summary: "v0.04-10 legacy ordering verification (#{phase.upcase}): #{status} (#{failures.size} failures)"
      }
    end
  end
end
