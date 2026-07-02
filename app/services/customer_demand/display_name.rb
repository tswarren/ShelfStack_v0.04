# frozen_string_literal: true

module CustomerDemand
  class DisplayName
    def self.for_reservation(reservation)
      reservation.customer&.display_name ||
        reservation.customer_request_line&.customer_request&.display_customer_name ||
        "—"
    end

    def self.for_demand_line(demand_line)
      demand_line.customer&.display_name ||
        demand_line.customer_name_snapshot.presence ||
        "—"
    end
  end
end
