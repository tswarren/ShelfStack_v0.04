# frozen_string_literal: true

module Sourcing
  class RecordVendorResponse
    class RecordResponseError < StandardError; end

    def self.call!(sourcing_attempt:, actor:, response_status: nil, response_method: "manual",
                   quantity_confirmed: 0, quantity_backordered: 0, quantity_unavailable: 0,
                   quantity_canceled: 0, quantity_failed: 0, quantity_substitute_offered: 0,
                   final_response: false, accept_backorder: false, purchase_order_line: nil,
                   vendor_reference: nil, message: nil, expected_ship_date: nil, expected_arrival_date: nil,
                   notes: nil)
      new(
        sourcing_attempt:, actor:, response_status:, response_method:,
        quantity_confirmed:, quantity_backordered:, quantity_unavailable:,
        quantity_canceled:, quantity_failed:, quantity_substitute_offered:,
        final_response:, accept_backorder:, purchase_order_line:,
        vendor_reference:, message:, expected_ship_date:, expected_arrival_date:, notes:
      ).call!
    end

    def initialize(sourcing_attempt:, actor:, response_status: nil, response_method: "manual",
                   quantity_confirmed: 0, quantity_backordered: 0, quantity_unavailable: 0,
                   quantity_canceled: 0, quantity_failed: 0, quantity_substitute_offered: 0,
                   final_response: false, accept_backorder: false, purchase_order_line: nil,
                   vendor_reference: nil, message: nil, expected_ship_date: nil, expected_arrival_date: nil,
                   notes: nil)
      @sourcing_attempt = sourcing_attempt
      @actor = actor
      @response_status = response_status
      @response_method = response_method
      @quantity_confirmed = quantity_confirmed.to_i
      @quantity_backordered = quantity_backordered.to_i
      @quantity_unavailable = quantity_unavailable.to_i
      @quantity_canceled = quantity_canceled.to_i
      @quantity_failed = quantity_failed.to_i
      @quantity_substitute_offered = quantity_substitute_offered.to_i
      @final_response = final_response == true
      @accept_backorder = accept_backorder == true
      @purchase_order_line = purchase_order_line
      @vendor_reference = vendor_reference
      @message = message
      @expected_ship_date = expected_ship_date
      @expected_arrival_date = expected_arrival_date
      @notes = notes
    end

    def call!
      raise RecordResponseError, "Attempt must be submitted" unless sourcing_attempt.status == "submitted"

      response = nil

      SourcingAttempt.transaction do
        locked_attempt = SourcingAttempt.lock.find(sourcing_attempt.id)
        raise RecordResponseError, "Attempt must be submitted" unless locked_attempt.status == "submitted"

        now = Time.current
        derived_status = response_status || AttemptStatusDeriver.response_status_from_quantities(build_preview(locked_attempt))

        response = VendorResponse.create!(
          store: locked_attempt.store,
          sourcing_attempt: locked_attempt,
          vendor: locked_attempt.vendor,
          response_status: derived_status,
          response_method: response_method,
          responded_by_user: actor,
          responded_at: now,
          vendor_reference: vendor_reference,
          message: message,
          expected_ship_date: expected_ship_date,
          expected_arrival_date: expected_arrival_date,
          quantity_confirmed: quantity_confirmed,
          quantity_backordered: quantity_backordered,
          quantity_unavailable: quantity_unavailable,
          quantity_canceled: quantity_canceled,
          quantity_failed: quantity_failed,
          quantity_substitute_offered: quantity_substitute_offered,
          final_response: final_response,
          purchase_order_line: purchase_order_line,
          notes: notes
        )

        if final_response
          attempt_status = AttemptStatusDeriver.from_final_response(response)
          locked_attempt.update!(status: attempt_status) if attempt_status.present?

          apply_final_response_effects!(locked_attempt, response)

          if buyer_review_required?(po_line: purchase_order_line || locked_attempt.purchase_order_line)
            locked_attempt.update!(buyer_review_required: true)
          end
        end

        AuditEvents.record!(
          actor: actor,
          event_name: "vendor_response.recorded",
          auditable: response,
          details: response_audit_details(response, locked_attempt)
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "vendor_response.quantity_split",
          auditable: response,
          details: response_audit_details(response, locked_attempt)
        )

        RunStatusRecalculator.call!(sourcing_run: locked_attempt.sourcing_run.reload)
      end

      response.reload
    end

    private

    attr_reader :sourcing_attempt, :actor, :response_status, :response_method,
                :quantity_confirmed, :quantity_backordered, :quantity_unavailable,
                :quantity_canceled, :quantity_failed, :quantity_substitute_offered,
                :final_response, :accept_backorder, :purchase_order_line,
                :vendor_reference, :message, :expected_ship_date, :expected_arrival_date, :notes

    def apply_final_response_effects!(locked_attempt, response)
      po_line = purchase_order_line || locked_attempt.purchase_order_line

      if quantity_confirmed.positive?
        if po_line.present?
          validate_po_line_link!(
            demand_line: locked_attempt.demand_line,
            purchase_order_line: po_line,
            quantity: quantity_confirmed
          )
          allocation = DemandAllocations::AllocateInboundPurchaseOrder.call!(
            demand_line: locked_attempt.demand_line,
            purchase_order_line: po_line,
            actor: actor,
            quantity: quantity_confirmed,
            notes: notes
          )
          allocation.update!(
            sourcing_attempt: locked_attempt,
            vendor_response: response
          )
        end
      end

      if quantity_backordered.positive? && accept_backorder
        DemandAllocations::AllocateVendorBackorder.call!(
          demand_line: locked_attempt.demand_line,
          actor: actor,
          quantity: quantity_backordered,
          sourcing_attempt: locked_attempt,
          vendor_response: response,
          notes: notes
        )
      end
    end

    def buyer_review_required?(po_line:)
      return true if quantity_failed.positive?
      return true if quantity_unavailable.positive? || quantity_canceled.positive? || quantity_substitute_offered.positive?
      return true if quantity_backordered.positive? && !accept_backorder
      return true if quantity_confirmed.positive? && po_line.blank?

      false
    end

    def validate_po_line_link!(demand_line:, purchase_order_line:, quantity: nil)
      ValidatePoLineLink.call!(
        demand_line: demand_line,
        purchase_order_line: purchase_order_line,
        quantity: quantity
      )
    rescue ValidatePoLineLink::ValidationError => e
      raise RecordResponseError, e.message
    end

    def build_preview(attempt)
      VendorResponse.new(
        sourcing_attempt: attempt,
        quantity_confirmed: quantity_confirmed,
        quantity_backordered: quantity_backordered,
        quantity_unavailable: quantity_unavailable,
        quantity_canceled: quantity_canceled,
        quantity_failed: quantity_failed,
        quantity_substitute_offered: quantity_substitute_offered
      )
    end

    def response_audit_details(response, attempt)
      {
        "demand_number" => attempt.demand_line.demand_number,
        "sourcing_run_id" => attempt.sourcing_run_id,
        "sourcing_attempt_id" => attempt.id,
        "vendor_id" => attempt.vendor_id,
        "quantity_confirmed" => response.quantity_confirmed,
        "quantity_backordered" => response.quantity_backordered,
        "quantity_unavailable" => response.quantity_unavailable,
        "quantity_canceled" => response.quantity_canceled,
        "quantity_failed" => response.quantity_failed,
        "final_response" => response.final_response
      }
    end
  end
end
