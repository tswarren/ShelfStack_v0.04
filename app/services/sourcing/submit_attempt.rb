# frozen_string_literal: true

module Sourcing
  class SubmitAttempt
    class SubmitAttemptError < StandardError; end

    def self.call!(sourcing_attempt:, actor:, response_due_at: nil)
      new(sourcing_attempt:, actor:, response_due_at:).call!
    end

    def initialize(sourcing_attempt:, actor:, response_due_at: nil)
      @sourcing_attempt = sourcing_attempt
      @actor = actor
      @response_due_at = response_due_at
    end

    def call!
      raise SubmitAttemptError, "Attempt must be pending" unless sourcing_attempt.pending?
      raise SubmitAttemptError, "Sourcing run is not active" unless sourcing_attempt.sourcing_run.active?

      SourcingAttempt.transaction do
        locked_attempt = SourcingAttempt.lock.find(sourcing_attempt.id)
        raise SubmitAttemptError, "Attempt must be pending" unless locked_attempt.pending?

        snapshot = VendorSourceSnapshot.build(
          variant: locked_attempt.product_variant,
          vendor: locked_attempt.vendor,
          suggestion: resolve_suggestion(locked_attempt),
          manual_override: locked_attempt.manual_vendor_override?
        )
        capability = Vendors::CapabilityResolver.call(
          vendor: locked_attempt.vendor,
          product: locked_attempt.product,
          product_variant: locked_attempt.product_variant,
          product_vendor: snapshot.product_vendor_id ? ProductVendor.find_by(id: snapshot.product_vendor_id) : nil,
          product_variant_vendor: snapshot.product_variant_vendor_id ? ProductVariantVendor.find_by(id: snapshot.product_variant_vendor_id) : nil
        )
        now = Time.current

        locked_attempt.update!(
          status: "submitted",
          submitted_by_user: actor,
          submitted_at: now,
          response_due_at: response_due_at,
          vendor_name_snapshot: snapshot.vendor_name_snapshot,
          vendor_item_number_snapshot: snapshot.vendor_item_number_snapshot,
          source_level_snapshot: snapshot.source_level_snapshot,
          source_record_type: snapshot.source_record_type,
          source_record_id: snapshot.source_record_id,
          vendor_priority_snapshot: snapshot.vendor_priority_snapshot,
          estimated_unit_cost_cents_snapshot: snapshot.estimated_unit_cost_cents_snapshot,
          returnability_snapshot: snapshot.returnability_snapshot,
          product_variant_vendor_id: snapshot.product_variant_vendor_id || locked_attempt.product_variant_vendor_id,
          product_vendor_id: snapshot.product_vendor_id || locked_attempt.product_vendor_id,
          availability_workflow_snapshot: capability.availability_workflow,
          availability_source_snapshot: capability.availability_source,
          order_submission_method_snapshot: capability.order_submission_method,
          acknowledgment_method_snapshot: capability.acknowledgment_method,
          shipment_notice_method_snapshot: capability.shipment_notice_method,
          invoice_method_snapshot: capability.invoice_method,
          technical_acknowledgment_method_snapshot: capability.technical_acknowledgment_method,
          fulfillment_methods_supported_snapshot: capability.fulfillment_methods_supported,
          vendor_capability_source_snapshot: capability.capability_source
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_attempt.submitted",
          auditable: locked_attempt,
          details: {
            "demand_number" => locked_attempt.demand_line.demand_number,
            "sourcing_run_id" => locked_attempt.sourcing_run_id,
            "sourcing_attempt_id" => locked_attempt.id,
            "vendor_id" => locked_attempt.vendor_id,
            "quantity_requested" => locked_attempt.quantity_requested,
            "capability_snapshot" => {
              "availability_workflow" => capability.availability_workflow,
              "availability_source" => capability.availability_source,
              "order_submission_method" => capability.order_submission_method,
              "acknowledgment_method" => capability.acknowledgment_method,
              "shipment_notice_method" => capability.shipment_notice_method,
              "invoice_method" => capability.invoice_method,
              "technical_acknowledgment_method" => capability.technical_acknowledgment_method,
              "fulfillment_methods_supported" => capability.fulfillment_methods_supported,
              "capability_source" => capability.capability_source
            }
          }
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_attempt.capability_snapshotted",
          auditable: locked_attempt,
          details: {
            "vendor_id" => locked_attempt.vendor_id,
            "capability_source" => capability.capability_source
          }
        )
      end

      sourcing_attempt.reload
    end

    private

    attr_reader :sourcing_attempt, :actor, :response_due_at

    def resolve_suggestion(attempt)
      if attempt.manual_vendor_override?
        Purchasing::SuggestedVendorResolver::Result.new(
          vendor: attempt.vendor,
          product_variant_vendor: attempt.product_variant_vendor,
          product_vendor: attempt.product_vendor,
          source: "manual"
        )
      else
        Purchasing::SuggestedVendorResolver.for_variant(attempt.product_variant)
      end
    end
  end
end
