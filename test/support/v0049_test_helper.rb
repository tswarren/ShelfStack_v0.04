# frozen_string_literal: true

module V0049TestHelper
  def record_po_line_vendor_quantities!(po_line, confirmed:, backordered: 0, canceled: 0, source_type: "manual")
    po_line.vendor_quantity_sync_update = true
    po_line.update!(
      quantity_confirmed_by_vendor: confirmed,
      quantity_backordered_by_vendor: backordered,
      quantity_canceled_by_vendor: canceled,
      vendor_quantities_recorded_at: Time.current,
      vendor_quantities_source_type: source_type,
      vendor_quantity_state: Purchasing::PoLineQuantitySummary.for(po_line).derive_vendor_quantity_state
    )
    po_line
  end
end
