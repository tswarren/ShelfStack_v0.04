# frozen_string_literal: true

module Pos
  class PickupLookupPresenter
    def self.as_json(rows)
      rows.map do |row|
        if row.respond_to?(:demand_allocation_id)
          {
            demand_allocation_id: row.demand_allocation_id,
            demand_line_id: row.demand_line_id,
            customer_id: row.customer_id,
            customer_name: row.customer_name,
            demand_number: row.demand_number,
            variant_sku: row.variant_sku,
            variant_name: row.variant_name,
            quantity: row.quantity,
            expires_at: row.expires_at&.iso8601
          }
        else
          {
            reservation_id: row.reservation_id,
            customer_id: row.customer_id,
            customer_name: row.customer_name,
            request_number: row.request_number,
            request_id: row.request_id,
            variant_sku: row.variant_sku,
            variant_name: row.variant_name,
            quantity: row.quantity,
            expires_at: row.expires_at&.iso8601,
            reservation_type: row.reservation_type
          }
        end
      end
    end
  end
end
