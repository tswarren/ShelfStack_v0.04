# frozen_string_literal: true

module CustomerRequests
  class ShowPresenter
    def initialize(customer_request:, store:, contact_events:, audit_events:)
      @customer_request = customer_request
      @store = store
      @contact_events = contact_events
      @audit_events = audit_events
      load_supporting_data!
    end

    attr_reader :customer_request, :store, :contact_events, :audit_events,
                :active_reservations_by_line, :availability_by_variant, :draft_po_lines_by_variant, :vendors

    def line_cards
      @line_cards ||= customer_request.customer_request_lines.map do |line|
        LineShowPresenter.build(
          line: line,
          store: store,
          active_reservations: active_reservations_by_line[line.id] || [],
          availability: availability_by_variant[line.product_variant_id],
          draft_po_lines: draft_po_lines_by_variant[line.product_variant_id] || [],
          vendors: vendors
        )
      end
    end

    def metrics
      lines = customer_request.customer_request_lines
      [
        { label: "Lines", value: lines.size },
        { label: "Unmatched", value: lines.count { |line| line.product_variant_id.blank? } },
        { label: "Ready", value: line_cards.count { |card|
          card.ready_quantity.positive? || card.line.status == "ready_for_pickup"
        } }
      ]
    end

    def attention_items
      items = []
      unmatched = customer_request.customer_request_lines.count { |line| line.product_variant_id.blank? }
      if unmatched.positive?
        items << Purchasing::DocumentAttention::AttentionItem.new(
          message: "#{unmatched} line(s) still need a variant match.",
          link_path: nil,
          link_label: nil
        )
      end

      approved_count = customer_request.customer_request_lines.count { |line| line.special_order&.status == "approved" }
      if approved_count.positive?
        items << Purchasing::DocumentAttention::AttentionItem.new(
          message: "#{approved_count} approved special order(s) need PO attachment.",
          link_path: nil,
          link_label: nil
        )
      end
      items
    end

    def contact_panel_prominent?
      contact_relevant_line_cards.any?
    end

    def contact_relevant_line_cards
      line_cards.select(&:contact_relevant?)
    end

    def contact_line_options
      customer_request.customer_request_lines.map do |line|
        [ "Line #{line.line_number}: #{line.provisional_title.presence || line.product_variant&.sku || 'Item'}", line.id ]
      end
    end

    def unfillable_eligibility
      @unfillable_eligibility ||= UnfillableEligibility.check(customer_request)
    end

    def can_mark_unfillable?
      unfillable_eligibility.allowed
    end

    def unfillable_blockers
      unfillable_eligibility.reasons
    end

    private

    def load_supporting_data!
      lines = customer_request.customer_request_lines
      variant_ids = lines.filter_map(&:product_variant_id)

      @active_reservations_by_line = CustomerRequests::ReservationLookup.active_by_line_id(lines.map(&:id))

      @availability_by_variant = variant_ids.index_with do |variant_id|
        variant = ProductVariant.find(variant_id)
        {
          available: Inventory::Availability.available(store: store, variant: variant),
          on_hand: Inventory::Availability.on_hand(store: store, variant: variant)
        }
      end

      @draft_po_lines_by_variant = if variant_ids.any?
        PurchaseOrderLine.joins(:purchase_order)
                         .includes(:purchase_order, :vendor, :product_variant)
                         .where(
                           product_variant_id: variant_ids,
                           purchase_orders: { store_id: store.id, status: "draft" }
                         )
                         .group_by(&:product_variant_id)
      else
        {}
      end

      @vendors = Vendor.active_records.order(:name)
    end
  end
end
