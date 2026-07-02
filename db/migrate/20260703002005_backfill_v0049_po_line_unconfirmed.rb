# frozen_string_literal: true

class BackfillV0049PoLineUnconfirmed < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE purchase_order_lines
      SET vendor_quantity_state = 'unconfirmed',
          quantity_confirmed_by_vendor = 0,
          quantity_backordered_by_vendor = 0,
          quantity_canceled_by_vendor = 0,
          quantity_rejected_on_line = 0,
          quantity_closed_short = 0,
          vendor_quantities_recorded_at = NULL,
          vendor_quantities_source_type = NULL,
          vendor_quantities_source_id = NULL
    SQL
  end

  def down
    # no-op: backfill is idempotent baseline
  end
end
