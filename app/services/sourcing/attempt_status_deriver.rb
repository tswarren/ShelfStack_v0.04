# frozen_string_literal: true

module Sourcing
  module AttemptStatusDeriver
    module_function

    def from_final_response(vendor_response)
      attempt = vendor_response.sourcing_attempt
      total = vendor_response.quantity_total
      requested = attempt.quantity_requested

      return "failed" if vendor_response.quantity_failed == requested
      return "backordered" if vendor_response.quantity_backordered == requested && total == requested
      return "confirmed" if vendor_response.quantity_confirmed == requested && total == requested
      return "partially_confirmed" if total == requested

      nil
    end

    def response_status_from_quantities(vendor_response)
      q = vendor_response
      return "failed" if q.quantity_failed.positive? && q.quantity_total == q.sourcing_attempt.quantity_requested && q.quantity_failed == q.quantity_total
      return "backordered" if q.quantity_backordered == q.sourcing_attempt.quantity_requested
      return "confirmed" if q.quantity_confirmed == q.sourcing_attempt.quantity_requested
      return "substitute_offered" if q.quantity_substitute_offered.positive? && q.quantity_total == q.quantity_substitute_offered
      return "mixed" if [ q.quantity_confirmed, q.quantity_backordered, q.quantity_unavailable, q.quantity_canceled, q.quantity_failed, q.quantity_substitute_offered ].count(&:positive?) > 1

      "partially_confirmed"
    end
  end
end
