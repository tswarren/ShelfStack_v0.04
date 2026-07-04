# frozen_string_literal: true

module Orders
  class BuyerWorkbenchRowPresenter
    include Rails.application.routes.url_helpers

    STATE_LABELS = {
      "needs_ordering" => "Needs ordering",
      "awaiting_vendor" => "Awaiting vendor",
      "ready_for_po" => "Ready for PO",
      "on_draft_po" => "On draft PO",
      "on_order" => "On order",
      "received_pickup" => "Ready for pickup",
      "backordered" => "Backordered",
      "all" => "Open"
    }.freeze

    def initialize(demand_line:, store:, tab_key:, workflow: nil, suggested_vendor: nil, supply_summary: nil)
      @demand_line = demand_line
      @store = store
      @tab_key = tab_key
      @workflow = workflow
      @suggested_vendor = suggested_vendor
      @supply_summary = supply_summary
    end

    attr_reader :demand_line, :store, :tab_key

    def state_label
      STATE_LABELS.fetch(tab_key, "Open")
    end

    def customer_or_purpose
      if demand_line.customer.present?
        demand_line.display_customer_name
      else
        demand_line.capture_intent.humanize
      end
    end

    def qty_open
      supply_summary.unallocated_quantity
    end

    def suggested_vendor_name
      suggested_vendor&.vendor&.name || "—"
    end

    def supply_one_liner
      parts = []
      parts << "On hand #{supply_summary.on_hand_available}" if supply_summary.on_hand_available.positive?
      parts << "Inbound #{supply_summary.inbound_allocated_to_demand}" if supply_summary.inbound_allocated_to_demand.positive?
      parts << "Backorder #{supply_summary.vendor_backorder_quantity}" if supply_summary.vendor_backorder_quantity.positive?
      parts << "Planned #{supply_summary.planned_on_draft_po_quantity}" if supply_summary.planned_on_draft_po_quantity.positive?
      unresolved = supply_summary.unallocated_quantity
      parts << "Unresolved #{unresolved}" if unresolved.positive? && parts.empty?
      parts << "Unresolved #{unresolved}" if unresolved.positive? && parts.any?
      parts.presence&.join(" · ") || "Fully allocated"
    end

    def next_action_label
      workflow.queue_preview_label(tab_key)
    end

    def primary_action
      action = workflow.next_action
      case action.key
      when :create_po, :planned_po
        { label: "Create PO", path: new_orders_demand_po_builder_path(demand_line_ids: [ demand_line.id ]) }
      when :start_sourcing, :review_sourcing
        if workflow.active_sourcing_run.present?
          { label: "Open sourcing", path: sourcing_run_path(workflow.active_sourcing_run) }
        else
          { label: "Start sourcing", path: demand_demand_line_path(demand_line, anchor: "demand-sourcing-panel") }
        end
      when :review_inbound, :allocate_on_hand
        { label: action.primary_label, path: demand_demand_line_path(demand_line, anchor: action.anchor) }
      when :ready_for_pickup
        { label: "POS pickup", path: pos_root_path(pickup: demand_line.demand_number) }
      when :vendor_backorder
        { label: "Review sourcing", path: workflow.active_sourcing_run ? sourcing_run_path(workflow.active_sourcing_run) : sourcing_root_path }
      else
        { label: "Open demand", path: demand_demand_line_path(demand_line) }
      end
    end

    private

    def workflow
      @workflow ||= Demand::DemandLineWorkflowPresenter.new(demand_line: demand_line, store: store)
    end

    def supply_summary
      @supply_summary ||= DemandLines::SupplySummary.for(demand_line: demand_line, store: store)
    end

    def suggested_vendor
      return @suggested_vendor if @suggested_vendor

      variant = demand_line.product_variant
      return nil if variant.blank?

      @suggested_vendor = Purchasing::SuggestedVendorResolver.for_variant(variant)
    end
  end
end
