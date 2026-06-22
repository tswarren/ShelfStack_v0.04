# frozen_string_literal: true

module CustomerRequests
  class NotifyQueueQuery
    def self.qualifies?(line, store:)
      return false unless line.request_type == "notify"
      return false unless line.matched?
      return false if %w[completed cancelled unfillable].include?(line.status)
      return false unless Inventory::Availability.available(store: store, variant: line.product_variant).to_i.positive?
      return false if fully_reserved?(line)

      true
    end

    def self.fully_reserved?(line)
      active_qty = line.inventory_reservations.where(status: %w[active ready]).sum do |reservation|
        reservation.quantity_reserved - reservation.quantity_fulfilled - reservation.quantity_released
      end
      active_qty >= line.remaining_quantity
    end

    def self.customer_request_ids_for(store:)
      candidates = CustomerRequestLine.open_lines
                                      .where(request_type: "notify")
                                      .where.not(product_variant_id: nil)
                                      .joins(:customer_request)
                                      .where(customer_requests: { store_id: store.id })
                                      .includes(:product_variant, :inventory_reservations, :customer_request)

      candidates.filter_map do |line|
        line.customer_request_id if qualifies?(line, store: store)
      end.uniq
    end
  end
end
