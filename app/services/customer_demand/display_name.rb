# frozen_string_literal: true

module CustomerDemand
  class DisplayName
    def self.for_reservation(reservation)
      reservation.customer&.display_name ||
        reservation.customer_request_line&.customer_request&.display_customer_name ||
        "—"
    end
  end
end
