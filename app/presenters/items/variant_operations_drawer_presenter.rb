# frozen_string_literal: true

module Items
  class VariantOperationsDrawerPresenter
    include Rails.application.routes.url_helpers

    def self.for(item:, store:, user:, variant:)
      new(item:, store:, user:, variant:)
    end

    def initialize(item:, store:, user:, variant:)
      @item = item
      @store = store
      @user = user
      @variant = variant
    end

    attr_reader :item, :store, :user, :variant

    def variant_row
      @variant_row ||= operations_presenter.variant_rows.find { |row| row.variant.id == variant.id }
    end

    def operations_tab
      @operations_tab ||= ItemOperationsTabPresenter.new(
        item: item,
        store: store,
        user: user,
        highlight_variant: variant
      )
    end

    def warnings
      @warnings ||= OperationalWarningBuilder.for_variants(
        store: store,
        variants: [ variant ],
        contexts: OperationalWarningBuilder.default_contexts,
        item: item
      ).fetch(variant.id, [])
    end

    def recommended_actions
      operations_presenter.variant_drawer_actions(variant)
    end

    def demand_actions
      operations_presenter.variant_customer_demand_actions(variant)
    end

    def v004_demand_activity_present?
      return false unless customer_demand_visible?

      tab = operations_tab
      tab.variant_scoped_active_holds.any? ||
        tab.variant_scoped_incoming_reserves.any? ||
        tab.variant_scoped_special_order_demand_lines.any? ||
        tab.variant_scoped_manual_tbo_demand_lines.any?
    end

    def legacy_activity_present?
      return false unless customer_demand_visible?

      operations_tab.variant_scoped_customer_request_lines.any?
    end

    def availability_context
      operations_presenter.availability_context(variant)
    end

    def customer_demand_visible?
      operations_presenter.customer_demand_visible?
    end

    def availability_header
      ctx = availability_context
      row = variant_row
      inbound_allocated = variant_inbound_allocated_qty
      {
        on_hand: row&.on_hand || ctx&.on_hand || 0,
        reserved: row&.reserved || ctx&.reserved || 0,
        available: row&.available || ctx&.available || 0,
        on_order: row&.on_order || 0,
        inbound_allocated: inbound_allocated,
        inbound_available: [ (row&.on_order || 0) - inbound_allocated, 0 ].max
      }
    end

    def unified_open_demand_lines
      @unified_open_demand_lines ||= DemandLine.includes(:customer)
                                               .where(store: store, product_variant: variant)
                                               .where.not(status: DemandLine::TERMINAL_STATUSES)
                                               .order(created_at: :desc)
                                               .limit(20)
    end

    def buyer_state_for(demand_line)
      Demand::DemandLineWorkflowPresenter.next_action_label_for(demand_line, store: store)
    end

    def add_to_po_path
      ids = unified_open_demand_lines.map(&:id)
      return nil if ids.empty?
      return nil unless Authorization.allowed?(user: user, permission_key: "orders.purchase_orders.create", store: store)

      new_orders_demand_po_builder_path(demand_line_ids: ids)
    end

    def recent_activity_one_liner
      parts = []
      sales = operations_tab.sales_history_rows.select { |e| e.variant_sku == variant.sku }.first
      parts << "Last sold #{sales.sold_at.to_date}" if sales&.sold_at
      receipt = operations_tab.variant_scoped_receipt_lines.first
      parts << "Last received #{receipt.receipt.received_at&.to_date || receipt.receipt.created_at.to_date}" if receipt
      po = operations_tab.variant_scoped_purchase_order_lines.first
      parts << "Open PO ##{po.purchase_order_id}" if po
      parts.join(" · ").presence
    end

    private

    def variant_inbound_allocated_qty
      DemandAllocation.active_allocations.inbound_kind
                      .where(store: store, product_variant: variant)
                      .sum(:quantity_allocated)
    end

    def operations_presenter
      @operations_presenter ||= ItemOperationsPresenter.new(item: item, store: store, user: user)
    end
  end
end
