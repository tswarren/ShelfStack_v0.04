# frozen_string_literal: true

module CustomerRequests
  class ReservationLookup
    def self.active_by_line_id(line_ids)
      return {} if line_ids.blank?

      InventoryReservation.active_on_hand
                          .where(customer_request_line_id: line_ids)
                          .includes(:receipt_line, :product_variant, receipt_line: :receipt)
                          .order(:ready_at, :created_at)
                          .group_by(&:customer_request_line_id)
    end
  end
end
