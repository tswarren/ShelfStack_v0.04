# frozen_string_literal: true

module Sourcing
  class CreateAttempt
    class CreateAttemptError < StandardError; end

    def self.call!(sourcing_run:, actor:, vendor:, quantity:, manual_vendor_override: false,
                   override_reason: nil, override_authorized_by_user: nil,
                   purchase_order_line: nil, notes: nil)
      new(
        sourcing_run:, actor:, vendor:, quantity:, manual_vendor_override:, override_reason:,
        override_authorized_by_user:, purchase_order_line:, notes:
      ).call!
    end

    def initialize(sourcing_run:, actor:, vendor:, quantity:, manual_vendor_override: false,
                   override_reason: nil, override_authorized_by_user: nil,
                   purchase_order_line: nil, notes: nil)
      @sourcing_run = sourcing_run
      @actor = actor
      @vendor = vendor
      @quantity = quantity.to_i
      @manual_vendor_override = manual_vendor_override == true
      @override_reason = override_reason
      @override_authorized_by_user = override_authorized_by_user || (manual_vendor_override ? actor : nil)
      @purchase_order_line = purchase_order_line
      @notes = notes
    end

    def call!
      raise CreateAttemptError, "Quantity must be positive" unless quantity.positive?
      raise CreateAttemptError, "Sourcing run is not active" unless sourcing_run.active?
      raise CreateAttemptError, "Vendor must be active" unless vendor.active?

      variant = sourcing_run.product_variant
      policy = ProductVariants::OperationalPolicy.for(variant)
      unless policy.vendor_sourcing_applicable?
        raise CreateAttemptError, policy.vendor_sourcing_not_applicable_message || "Variant is not vendor-orderable"
      end

      if manual_vendor_override && override_authorized_by_user.blank?
        raise CreateAttemptError, "Override authorization is required"
      end

      attempt = nil
      SourcingRun.transaction do
        locked_run = SourcingRun.lock.find(sourcing_run.id)
        raise CreateAttemptError, "Sourcing run is not active" unless locked_run.active?

        run_unresolved = UnresolvedQuantity.for_sourcing_run(locked_run)
        raise CreateAttemptError, "Quantity exceeds run unresolved quantity (#{run_unresolved})" if quantity > run_unresolved

        suggestion = resolve_suggestion(variant)
        next_sequence = locked_run.sourcing_attempts.maximum(:sequence_number).to_i + 1
        now = Time.current

        attempt = locked_run.sourcing_attempts.create!(
          store: locked_run.store,
          demand_line: locked_run.demand_line,
          product: locked_run.product,
          product_variant: locked_run.product_variant,
          vendor: vendor,
          product_variant_vendor_id: suggestion&.product_variant_vendor&.id,
          product_vendor_id: suggestion&.product_vendor&.id,
          purchase_order_line: purchase_order_line,
          status: "pending",
          sequence_number: next_sequence,
          quantity_requested: quantity,
          manual_vendor_override: manual_vendor_override,
          manual_override_reason: manual_vendor_override ? override_reason : nil,
          override_authorized_by_user: manual_vendor_override ? override_authorized_by_user : nil,
          override_authorized_at: manual_vendor_override ? now : nil,
          notes: notes
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_attempt.created",
          auditable: attempt,
          details: {
            "demand_number" => locked_run.demand_line.demand_number,
            "sourcing_run_id" => locked_run.id,
            "sourcing_attempt_id" => attempt.id,
            "vendor_id" => vendor.id,
            "quantity_requested" => quantity,
            "manual_vendor_override" => manual_vendor_override
          }
        )

        if manual_vendor_override
          AuditEvents.record!(
            actor: override_authorized_by_user,
            event_name: "sourcing.manual_vendor_override",
            auditable: attempt,
            details: {
              "demand_number" => locked_run.demand_line.demand_number,
              "vendor_id" => vendor.id,
              "manual_override_reason" => override_reason
            }
          )
        end
      end

      attempt.reload
    end

    private

    attr_reader :sourcing_run, :actor, :vendor, :quantity, :manual_vendor_override,
                :override_reason, :override_authorized_by_user, :purchase_order_line, :notes

    def resolve_suggestion(variant)
      if manual_vendor_override
        Purchasing::SuggestedVendorResolver::Result.new(
          vendor: vendor,
          product_variant_vendor: nil,
          product_vendor: nil,
          source: "manual"
        )
      else
        Purchasing::SuggestedVendorResolver.for_variant(variant)
      end
    end
  end
end
