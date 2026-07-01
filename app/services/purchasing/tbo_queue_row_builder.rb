# frozen_string_literal: true

module Purchasing
  class TboQueueRowBuilder
    Row = Data.define(
      :line,
      :sourcing,
      :suggested_vendor,
      :po_eligibility,
      :quantity_on_hand,
      :quantity_on_order,
      :quantity_pending,
      :open_tbo_quantity,
      :remaining_quantity
    )

    def self.call(store:, vendor: nil, sourced_only: false, department_id: nil, format_id: nil)
      new(
        store:,
        vendor:,
        sourced_only:,
        department_id:,
        format_id:
      ).call
    end

    def initialize(store:, vendor: nil, sourced_only: false, department_id: nil, format_id: nil)
      @store = store
      @vendor = vendor
      @sourced_only = sourced_only
      @department_id = department_id
      @format_id = format_id
    end

    def call
      return [] if store.blank?

      lines = filtered_lines
      return [] if lines.empty?

      variant_ids = lines.map(&:product_variant_id).uniq
      line_ids = lines.map(&:id)

      balances = InventoryBalance
        .where(store: store, product_variant_id: variant_ids)
        .index_by(&:product_variant_id)
      order_quantities = OrderQuantityLookup.for_variants(store: store, variant_ids: variant_ids)
      open_tbo_quantities = open_tbo_quantities_for(variant_ids)
      ordered_quantities = PurchaseRequestLine.ordered_quantities_for(line_ids)
      suggested_vendors = SuggestedVendorResolver.for_variants(variant_ids)

      rows = lines.filter_map do |line|
        remaining = line.requested_quantity - ordered_quantities.fetch(line.id, 0)
        next if remaining <= 0

        variant_id = line.product_variant_id
        sourcing = vendor.present? ? SourcingLookup.for(variant: line.product_variant, vendor: vendor) : nil
        order_qty = order_quantities.fetch(variant_id) { OrderQuantityLookup.zero_result }

        Row.new(
          line: line,
          sourcing: sourcing,
          suggested_vendor: suggested_vendors.fetch(variant_id) { SuggestedVendorResolver.for_variant(line.product_variant) },
          po_eligibility: OrderEligibilityResolver.call(
            product_variant: line.product_variant,
            vendor: vendor,
            context: :purchase_order
          ),
          quantity_on_hand: balances[variant_id]&.quantity_on_hand || 0,
          quantity_on_order: order_qty.on_order,
          quantity_pending: order_qty.pending,
          open_tbo_quantity: open_tbo_quantities.fetch(variant_id, 0),
          remaining_quantity: remaining
        )
      end

      rows = rows.select { |row| row.sourcing&.sourcing_record_present } if sourced_only && vendor.present?
      rows
    end

    private

    attr_reader :store, :vendor, :sourced_only, :department_id, :format_id

    def filtered_lines
      scope = PurchaseRequestLine
        .buildable_for_store(store)
        .includes(product_variant: [ :sub_department, { product: :format } ], purchase_request: :store)
        .order("purchase_requests.created_at DESC, purchase_request_lines.line_number ASC")

      if department_id.present?
        scope = scope.joins(product_variant: :sub_department)
          .where(sub_departments: { department_id: department_id })
      end

      if format_id.present?
        scope = scope.joins(product_variant: :product)
          .where(products: { format_id: format_id })
      end

      scope.to_a
    end

    def open_tbo_quantities_for(variant_ids)
      PurchaseRequestLine.open_remaining_quantities_for(store: store, variant_ids: variant_ids)
    end
  end
end
