# frozen_string_literal: true

module Items
  class VariantOperationalSnapshot
    Row = Data.define(
      :variant_id,
      :on_hand,
      :available,
      :reserved,
      :legacy_on_hand_reserved,
      :v0047_on_hand_reserved,
      :on_order_available,
      :ready_for_pickup_qty,
      :open_tbo,
      :pending_po,
      :on_order,
      :last_received,
      :suggested_vendor,
      :vendor_item_number,
      :returnability_status,
      :orderable,
      :inventory_tracking,
      :sourcing_record_present,
      :expected_unit_cost_cents
    )

    def self.for_variants(store:, variants:, user: nil, item: nil)
      new(store:, variants:, user:, item:).build
    end

    def initialize(store:, variants:, user: nil, item: nil)
      @store = store
      @variants = Array(variants).compact.uniq
      @user = user
      @item = item
    end

    def build
      self
    end

    def rows
      @rows ||= build_rows
    end

    def suggested_vendors
      @suggested_vendors ||= Purchasing::SuggestedVendorResolver.for_variants(variant_ids)
    end

    def last_received
      @last_received ||= Purchasing::LastReceivedLookup.for_variants(store: store, variant_ids: variant_ids)
    end

    def sourcing_by_variant_id
      @sourcing_by_variant_id ||= begin
        vendors_by_variant_id = suggested_vendors.transform_values { |result| result.vendor }
        Purchasing::SourcingLookup.for_variants(variants:, vendors_by_variant_id:)
      end
    end

    private

    attr_reader :store, :variants, :user, :item

    def variant_ids
      @variant_ids ||= variants.map(&:id)
    end

    def build_rows
      return {} if store.blank? || variant_ids.empty?

      balances = InventoryBalance.where(store: store, product_variant_id: variant_ids).index_by(&:product_variant_id)
      legacy_on_hand_reserved = legacy_on_hand_reserved_by_variant
      v0047_on_hand_reserved = v0047_on_hand_reserved_by_variant
      order_quantities = Purchasing::OrderQuantityLookup.for_variants(store: store, variant_ids: variant_ids)
      open_tbo = PurchaseRequestLine.open_remaining_quantities_for(store: store, variant_ids: variant_ids)
      ready_for_pickup = ready_for_pickup_quantities_for
      vendors = suggested_vendors
      received = last_received
      sourcing_results = sourcing_by_variant_id
      reserved_incoming = reserved_incoming_by_variant

      variants.index_with do |variant|
        eligible = Inventory::Eligibility.eligible?(variant)
        balance = balances[variant.id]
        order_qty = order_quantities.fetch(variant.id) { Purchasing::OrderQuantityLookup.zero_result }
        suggested = vendors.fetch(variant.id) { Purchasing::SuggestedVendorResolver.for_variant(variant) }
        vendor = suggested.vendor
        sourcing = sourcing_results[variant.id]
        reserved_incoming_qty = reserved_incoming.fetch(variant.id, 0)

        Row.new(
          variant_id: variant.id,
          on_hand: eligible ? (balance&.quantity_on_hand || 0) : nil,
          available: eligible ? (balance&.quantity_available || 0) : nil,
          reserved: eligible ? (balance&.quantity_reserved || 0) : nil,
          legacy_on_hand_reserved: eligible ? legacy_on_hand_reserved.fetch(variant.id, 0) : nil,
          v0047_on_hand_reserved: eligible ? v0047_on_hand_reserved.fetch(variant.id, 0) : nil,
          on_order_available: eligible ? [ order_qty.on_order - reserved_incoming_qty, 0 ].max : nil,
          ready_for_pickup_qty: ready_for_pickup.fetch(variant.id, 0),
          open_tbo: open_tbo.fetch(variant.id, 0),
          pending_po: eligible ? order_qty.pending : nil,
          on_order: eligible ? order_qty.on_order : nil,
          last_received: received[variant.id],
          suggested_vendor: suggested,
          vendor_item_number: sourcing&.vendor_item_number,
          returnability_status: vendor.present? ? Purchasing::ReturnabilityResolver.resolve(variant: variant, vendor: vendor) : nil,
          orderable: variant.orderable?,
          inventory_tracking: Inventory::TrackingResolver.resolve(variant),
          sourcing_record_present: sourcing&.sourcing_record_present == true,
          expected_unit_cost_cents: expected_unit_cost_cents(variant:, vendor:, sourcing:)
        )
      end.transform_keys(&:id)
    end

    def expected_unit_cost_cents(variant:, vendor:, sourcing:)
      return nil if vendor.blank?

      defaults = Purchasing::LinePriceDefaults.resolve(
        variant: variant,
        vendor: vendor,
        sourcing: sourcing
      )
      return nil if defaults.unit_cost_cents.nil?
      return nil if defaults.unit_cost_cents.zero? && defaults.unit_list_price_cents.to_i.zero?

      defaults.unit_cost_cents
    end

    def ready_for_pickup_quantities_for
      InventoryReservation.active_on_hand
                          .where(store: store, product_variant_id: variant_ids, status: "ready")
                          .group(:product_variant_id)
                          .sum("quantity_reserved - quantity_fulfilled - quantity_released")
    end

    def reserved_incoming_by_variant
      InventoryReservation.active_incoming
                          .where(store: store, product_variant_id: variant_ids)
                          .group(:product_variant_id)
                          .sum("quantity_reserved - quantity_fulfilled - quantity_released")
    end

    def legacy_on_hand_reserved_by_variant
      InventoryReservation.active_on_hand
                          .where(store: store, product_variant_id: variant_ids)
                          .group(:product_variant_id)
                          .sum("quantity_reserved - quantity_fulfilled - quantity_released")
    end

    def v0047_on_hand_reserved_by_variant
      DemandAllocation.active_allocations
                      .on_hand_kind
                      .where(store: store, product_variant_id: variant_ids)
                      .group(:product_variant_id)
                      .sum(:quantity_allocated)
    end
  end
end
