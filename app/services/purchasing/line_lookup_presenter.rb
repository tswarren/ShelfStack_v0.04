# frozen_string_literal: true

module Purchasing
  class LineLookupPresenter
    def self.as_json(result, store:, vendor: nil, purchase_order: nil)
      new(result, store:, vendor:, purchase_order:).as_json
    end

    def initialize(result, store:, vendor: nil, purchase_order: nil)
      @result = result
      @store = store
      @vendor = vendor
      @purchase_order = purchase_order
    end

    def as_json
      {
        status: result.status.to_s,
        message: result.message,
        matches: result.matches.map { |match| match_json(match) }
      }
    end

    private

    attr_reader :result, :store, :vendor, :purchase_order

    def match_json(match)
      variant = match.variant
      balance = InventoryBalance.find_by(store: store, product_variant: variant)
      sourcing = vendor.present? ? SourcingLookup.for(variant:, vendor:) : nil
      order_qty = Purchasing::OrderQuantityLookup.for_variant(store: store, variant: variant)
      defaults = LinePriceDefaults.resolve(
        variant: variant,
        vendor: vendor,
        purchase_order_line: match.purchase_order_line
      )

      json = {
        id: variant.id,
        sku: variant.sku,
        name: variant.name,
        condition: variant.condition&.short_name,
        inventory_behavior: variant.inventory_behavior,
        eligible: Inventory::Eligibility.eligible?(variant),
        vendor_item_number: sourcing&.vendor_item_number,
        sourcing_record_present: sourcing&.sourcing_record_present || false,
        preferred: sourcing&.preferred || false,
        returnability_status: ReturnabilityResolver.resolve(variant:, vendor: vendor),
        quantity_on_hand: balance&.quantity_on_hand || 0,
        quantity_on_order: order_qty.on_order,
        open_tbo_quantity: open_tbo_quantity(variant),
        moving_average_unit_cost_cents: balance&.moving_average_unit_cost_cents,
        last_received_cost_cents: last_received_cost_cents(variant),
        unit_list_price_cents: defaults.unit_list_price_cents,
        supplier_discount_bps: defaults.supplier_discount_bps,
        unit_cost_cents: defaults.unit_cost_cents
      }

      if match.purchase_order_line.present?
        po_line = match.purchase_order_line
        json[:purchase_order_line_id] = po_line.id
        json[:quantity_expected] = [ po_line.quantity_ordered - po_line.quantity_received, 0 ].max
        json[:customer_reserved_open] = ReceiptLineDemand.customer_reserved_open(po_line)
      end

      json
    end

    def open_tbo_quantity(variant)
      PurchaseRequestLine
        .buildable_for_store(store)
        .where(product_variant: variant)
        .sum(:requested_quantity)
    end

    def last_received_cost_cents(variant)
      Purchasing::LastReceivedLookup.for_variant(store: store, variant: variant)&.unit_cost_cents
    end
  end
end
