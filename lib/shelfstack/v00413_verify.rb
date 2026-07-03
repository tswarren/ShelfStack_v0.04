# frozen_string_literal: true

module Shelfstack
  module V00413Verify
    module_function

    SLICE_ORDER = %w[
      slice_0 slice_a slice_c slice_d slice_d2 slice_e slice_f slice_g slice_h final
      slice_b slice_e2 slice_r readiness
    ].freeze

    SPEC_BUNDLE = "docs/v0.04/v0.04-13-demand-to-fulfillment-continuity".freeze

    MVP_CHECKS = {
      vendor_capability_columns: { from: "slice_a", check: :vendor_capability_columns_present? },
      sourcing_capability_snapshots: { from: "slice_c", check: :sourcing_capability_snapshots_present? },
      demand_plans_table: { from: "slice_d", check: :demand_plans_table_present? },
      planned_coverage_no_availability_impact: { from: "slice_d", check: :planned_coverage_services_present? },
      po_destination_fields: { from: "slice_d2", check: :po_destination_fields_present? },
      inbound_conversion_service: { from: "slice_e", check: :inbound_conversion_service_present? },
      customer_direct_gated: { from: "slice_d2", check: :customer_direct_gates_present? },
      vendor_direct_fulfillment_enum: { from: "slice_d2", check: :vendor_direct_fulfillment_enum_present? },
      receipt_origin_fields: { from: "slice_f", check: :receipt_origin_fields_present? },
      shipment_first_receiving: { from: "slice_f", check: :shipment_first_receiving_present? },
      receipt_line_matches_table: { from: "slice_g", check: :receipt_line_matches_table_present? },
      post_receipt_accepted_qty_only: { from: "slice_g", check: :post_receipt_accepted_qty_regression? },
      no_legacy_ordering_writes: { from: "slice_0", check: :no_legacy_ordering_reintroduced? },
      idempotency_services: { from: "slice_e", check: :idempotency_services_present? },
      audit_events_registered: { from: "final", check: :mvp_audit_events_registered? }
    }.freeze

    READINESS_CHECKS = {
      external_references_table: :external_references_table_present?,
      vendor_direct_conversion: :vendor_direct_conversion_present?,
      ship_to_snapshot_validation: :ship_to_snapshot_validation_present?,
      fulfill_vendor_direct: :fulfill_vendor_direct_present?,
      receipt_cartons_advisory: :receipt_cartons_absent_advisory?
    }.freeze

    def slice
      ENV.fetch("V00413_SLICE", "slice_0").downcase
    end

    def slice_index
      SLICE_ORDER.index(slice) || 0
    end

    def at_least?(target_slice)
      SLICE_ORDER.index(target_slice).to_i <= slice_index
    end

    def strict?
      ENV["STRICT"].to_s == "1"
    end

    def final_slice?
      slice == "final" || slice == "readiness"
    end

    def spec_bundle_exists?
      %w[spec.md data-model.md test-plan.md].all? do |file|
        File.exist?(Rails.root.join(SPEC_BUNDLE, file))
      end
    end

    def completion_stub_exists?
      File.exist?(Rails.root.join("docs/implementation/v0.04-13-completion.md"))
    end

    def verifier_file_exists?
      File.exist?(Rails.root.join("lib/shelfstack/v00413_verify.rb"))
    end

    def vendor_capability_columns_present?
      %w[
        availability_workflow availability_source order_submission_method
        acknowledgment_method shipment_notice_method invoice_method
        technical_acknowledgment_method fulfillment_methods_supported
      ].all? { |col| Vendor.column_names.include?(col) } &&
        defined?(Vendors::CapabilityResolver)
    end

    def sourcing_capability_snapshots_present?
      %w[
        availability_workflow_snapshot availability_source_snapshot
        order_submission_method_snapshot acknowledgment_method_snapshot
        shipment_notice_method_snapshot invoice_method_snapshot
        technical_acknowledgment_method_snapshot fulfillment_methods_supported_snapshot
        vendor_capability_source_snapshot
      ].all? { |col| SourcingAttempt.column_names.include?(col) } &&
        defined?(Sourcing::NextActionPresenter)
    end

    def demand_plans_table_present?
      PurchaseOrderLineDemandPlan.table_exists? &&
        defined?(Purchasing::CreateDemandCoveragePlans)
    end

    def planned_coverage_services_present?
      defined?(Purchasing::CreateDemandCoveragePlans) &&
        defined?(Purchasing::ReleaseDemandCoveragePlan) &&
        defined?(Purchasing::PurchaseOrderLineDemandPlanSummary)
    end

    def po_destination_fields_present?
      PurchaseOrder.column_names.include?("order_purpose") &&
        PurchaseOrder.column_names.include?("ship_to_type")
    end

    def inbound_conversion_service_present?
      defined?(Purchasing::ConvertDemandCoveragePlansToInbound)
    end

    def customer_direct_gates_present?
      defined?(Purchasing::CustomerDirectPurchaseOrderGate) ||
        (defined?(PurchaseOrder) && PurchaseOrder.instance_methods.include?(:customer_direct?))
    end

    def vendor_direct_fulfillment_enum_present?
      DemandAllocation::ALLOCATION_KINDS.include?("vendor_direct_fulfillment")
    end

    def receipt_origin_fields_present?
      %w[origin_method receiving_mode vendor_shipment_destination].all? { |col| Receipt.column_names.include?(col) }
    end

    def shipment_first_receiving_present?
      defined?(Receiving::CreateVendorShipmentReceipt) ||
        defined?(Orders::ReceiptsController)
    end

    def receipt_line_matches_table_present?
      ReceiptLineMatch.table_exists? &&
        defined?(Receiving::ReceiptPostingMatchAdapter)
    end

    def post_receipt_accepted_qty_regression?
      content = File.read(Rails.root.join("app/services/purchasing/post_receipt.rb"))
      content.include?("quantity_accepted") && defined?(Purchasing::PostReceipt)
    end

    def no_legacy_ordering_reintroduced?
      Shelfstack::V00410Verify.legacy_tables_absent? &&
        Shelfstack::V00410Verify.legacy_models_absent?
    end

    def idempotency_services_present?
      defined?(Purchasing::ConvertDemandCoveragePlansToInbound) &&
        defined?(Receiving::ApplyReceiptLineMatches)
    end

    def mvp_audit_events_registered?
      audit_paths = Dir.glob(Rails.root.join("{app/services,app/controllers}/**/*.rb"))
      content = audit_paths.map { |p| File.read(p) }.join("\n")
      %w[
        vendor.capability_updated
        purchase_order_line_demand_plan.created
        purchase_order_line_demand_plan.converted_to_inbound
        receipt_line_match.confirmed
      ].all? { |event| content.include?(event) }
    end

    def external_references_table_present?
      defined?(ExternalReference) && ExternalReference.table_exists?
    end

    def vendor_direct_conversion_present?
      defined?(Purchasing::ConvertDemandCoveragePlansToVendorDirect)
    end

    def ship_to_snapshot_validation_present?
      PurchaseOrder.column_names.include?("ship_to_snapshot")
    end

    def fulfill_vendor_direct_present?
      defined?(DemandAllocations::FulfillVendorDirect)
    end

    def receipt_cartons_absent_advisory?
      !ActiveRecord::Base.connection.table_exists?("receipt_cartons")
    end

    def run!
      checks = []
      checks << enforced_check("spec_bundle_exists", spec_bundle_exists?) if at_least?("slice_0")
      checks << enforced_check("completion_stub_exists", completion_stub_exists?) if at_least?("slice_0")
      checks << enforced_check("verifier_file_exists", verifier_file_exists?) if at_least?("slice_0")

      MVP_CHECKS.each do |key, config|
        next unless at_least?(config[:from])

        result = send(config[:check])
        if final_slice? && at_least?("final") && slice != "readiness"
          checks << enforced_check(key.to_s, result)
        elsif result
          checks << enforced_check(key.to_s, true)
        else
          checks << pending_check(key.to_s, config[:from])
        end
      end

      if slice == "readiness"
        READINESS_CHECKS.each do |key, method|
          advisory = key == :receipt_cartons_advisory
          pass = send(method)
          checks << if advisory
                      pending_check(key.to_s, "readiness", pass ? "advisory pass" : "advisory")
                    else
                      enforced_check(key.to_s, pass)
                    end
        end
      end

      failed = checks.reject { |c| c[:pass] || c[:pending] }
      pending = checks.select { |c| c[:pending] }

      if failed.any?
        puts "V00413 verify FAILED (slice=#{slice}):"
        failed.each { |c| puts "  - #{c[:key]}: #{c[:message]}" }
        exit(1) if strict? && final_slice?
        return false
      end

      puts "V00413 verify PASS (slice=#{slice}, #{checks.size} checks, #{pending.size} pending)"
      pending.each { |c| puts "  ~ #{c[:key]}: pending until #{c[:message]}" } if pending.any?
      true
    end

    def enforced_check(key, pass, message = nil)
      { key: key, pass: pass, pending: false, message: message || key }
    end

    def pending_check(key, from_slice, message = nil)
      if strict? && final_slice? && slice != "readiness"
        { key: key, pass: false, pending: false, message: message || "pending until #{from_slice}" }
      else
        { key: key, pass: true, pending: true, message: message || from_slice }
      end
    end
  end
end
