# frozen_string_literal: true

module Sourcing
  module AttemptStatusDeriver
    QUANTITY_BUCKETS = VendorResponse::QUANTITY_FIELDS

    module_function

    def from_final_response(vendor_response)
      attempt = vendor_response.sourcing_attempt
      requested = attempt.quantity_requested
      return nil unless vendor_response.quantity_total == requested

      q = vendor_response

      return "confirmed" if q.quantity_confirmed == requested
      return "backordered" if q.quantity_backordered == requested
      return "canceled" if q.quantity_canceled == requested
      return "failed" if q.quantity_failed == requested
      return "failed" if q.quantity_unavailable == requested
      return "failed" if q.quantity_substitute_offered == requested

      return "partially_confirmed" if q.quantity_confirmed.positive?

      "failed"
    end

    def response_status_from_quantities(vendor_response)
      q = vendor_response
      requested = q.sourcing_attempt.quantity_requested

      return "confirmed" if q.quantity_confirmed == requested
      return "backordered" if q.quantity_backordered == requested
      return "unavailable" if q.quantity_unavailable == requested
      return "canceled" if q.quantity_canceled == requested
      return "failed" if q.quantity_failed == requested
      return "substitute_offered" if q.quantity_substitute_offered == requested

      return "partially_confirmed" if q.quantity_confirmed.positive?
      return "mixed" if quantity_bucket_count(q) > 1

      "mixed"
    end

    def quantity_bucket_count(vendor_response)
      QUANTITY_BUCKETS.count { |field| vendor_response.public_send(field).to_i.positive? }
    end
  end
end
