# frozen_string_literal: true

module Sourcing
  class Cascade
    class CascadeError < StandardError; end

    def self.call!(previous_attempt:, actor:, vendor:, quantity:, cascade_reason:, manual_vendor_override: false,
                   override_reason: nil, override_authorized_by_user: nil, notes: nil)
      new(
        previous_attempt:, actor:, vendor:, quantity:, cascade_reason:,
        manual_vendor_override:, override_reason:, override_authorized_by_user:, notes:
      ).call!
    end

    def initialize(previous_attempt:, actor:, vendor:, quantity:, cascade_reason:,
                   manual_vendor_override: false, override_reason: nil, override_authorized_by_user: nil, notes: nil)
      @previous_attempt = previous_attempt
      @actor = actor
      @vendor = vendor
      @quantity = quantity.to_i
      @cascade_reason = cascade_reason
      @manual_vendor_override = manual_vendor_override == true
      @override_reason = override_reason
      @override_authorized_by_user = override_authorized_by_user || (manual_vendor_override ? actor : nil)
      @notes = notes
    end

    def call!
      raise CascadeError, "Cascade reason is required" if cascade_reason.blank?
      raise CascadeError, "Quantity must be positive" unless quantity.positive?

      eligible = CascadeEligibleQuantity.for_attempt(previous_attempt)
      raise CascadeError, "Attempt has no cascade-eligible quantity" unless eligible.positive?
      raise CascadeError, "Quantity exceeds cascade-eligible quantity (#{eligible})" if quantity > eligible

      run = previous_attempt.sourcing_run
      demand_unresolved = UnresolvedQuantity.for_demand_line(previous_attempt.demand_line)
      raise CascadeError, "Quantity exceeds demand unresolved quantity (#{demand_unresolved})" if quantity > demand_unresolved

      attempt = nil

      SourcingAttempt.transaction do
        locked_previous = SourcingAttempt.lock.find(previous_attempt.id)
        locked_run = SourcingRun.lock.find(run.id)

        attempt = CreateAttempt.call!(
          sourcing_run: locked_run,
          actor: actor,
          vendor: vendor,
          quantity: quantity,
          manual_vendor_override: manual_vendor_override,
          override_reason: override_reason,
          override_authorized_by_user: override_authorized_by_user,
          notes: notes
        )

        attempt.update!(
          previous_sourcing_attempt: locked_previous,
          cascade_reason: cascade_reason
        )

        if locked_previous.status.in?(%w[submitted partially_confirmed backordered failed])
          locked_previous.update!(status: "cascaded")
        end

        AuditEvents.record!(
          actor: actor,
          event_name: "sourcing_attempt.cascaded",
          auditable: attempt,
          details: {
            "demand_number" => locked_previous.demand_line.demand_number,
            "previous_sourcing_attempt_id" => locked_previous.id,
            "sourcing_attempt_id" => attempt.id,
            "vendor_id" => vendor.id,
            "quantity_requested" => quantity,
            "cascade_reason" => cascade_reason
          }
        )

        RunStatusRecalculator.call!(sourcing_run: locked_run.reload)
      end

      attempt.reload
    end

    private

    attr_reader :previous_attempt, :actor, :vendor, :quantity, :cascade_reason,
                :manual_vendor_override, :override_reason, :override_authorized_by_user, :notes
  end
end
