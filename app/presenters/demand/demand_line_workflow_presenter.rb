# frozen_string_literal: true

module Demand
  class DemandLineWorkflowPresenter
    NextAction = Data.define(
      :key,
      :title,
      :body,
      :kind,
      :primary_label,
      :primary_path,
      :primary_method,
      :primary_params,
      :secondary_label,
      :secondary_path,
      :anchor
    )

    TimelineEvent = Data.define(:label, :occurred_at, :detail)

    def self.next_action_label_for(demand_line, queue_key: nil, store: demand_line.store)
      new(demand_line:, store:).queue_preview_label(queue_key)
    end

    def initialize(demand_line:, store:, active_sourcing_run: nil, latest_vendor_response: nil,
                   sourcing_unresolved: nil, sourcing_eligibility: nil)
      @demand_line = demand_line
      @store = store
      @active_sourcing_run = active_sourcing_run
      @latest_vendor_response = latest_vendor_response
      @sourcing_unresolved = sourcing_unresolved
      @sourcing_eligibility = sourcing_eligibility
    end

    attr_reader :demand_line, :store, :active_sourcing_run, :latest_vendor_response,
                :sourcing_unresolved, :sourcing_eligibility

    def supply_summary
      @supply_summary ||= DemandLines::SupplySummary.for(demand_line:, store:)
    end

    def next_action
      @next_action ||= build_next_action
    end

    def timeline_events
      @timeline_events ||= build_timeline
    end

    def queue_preview_label(queue_key)
      case next_action.key
      when :ready_for_pickup then "POS pickup"
      when :notify_customer then "Contact customer"
      when :match_variant then "Match variant"
      when :start_sourcing, :review_sourcing then queue_key == "awaiting_response" ? "Review sourcing" : "Start sourcing"
      when :allocate_on_hand then "Allocate on hand"
      when :review_inbound then "Review inbound"
      when :vendor_backorder then "Vendor backorder"
      when :planned_po, :create_po then "PO action"
      when :terminal then "No action required"
      else
        "View demand"
      end
    end

    private

    def build_next_action
      if demand_line.terminal?
        return terminal_action
      end

      if demand_line.status == "captured"
        return match_variant_action
      end

      if ready_for_pickup?
        return pickup_action
      end

      if supply_summary.vendor_backorder_quantity.positive? && supply_summary.unallocated_quantity.positive?
        return vendor_backorder_action
      end

      if supply_summary.planned_on_draft_po_quantity.positive? &&
         supply_summary.inbound_allocated_to_demand.zero? &&
         supply_summary.unallocated_quantity.positive?
        return planned_po_action
      end

      if vendor_confirmed_needs_po?
        return create_po_action
      end

      if active_sourcing_run.present?
        return review_sourcing_action
      end

      if supply_summary.unallocated_quantity.positive?
        if supply_summary.inbound_available.positive?
          return review_inbound_action
        end

        if supply_summary.on_hand_available.positive?
          return allocate_on_hand_action
        end

        if sourcing_eligible?
          return start_sourcing_action
        end
      end

      if demand_line.capture_intent == "notify" && supply_summary.on_hand_available.positive?
        return notify_customer_action
      end

      info_action("Review demand details", "No automatic next step is available.")
    end

    def terminal_action
      NextAction.new(
        key: :terminal,
        title: "No further action required",
        body: "This demand is #{demand_line.status.humanize.downcase}.",
        kind: :info,
        primary_label: nil,
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def match_variant_action
      NextAction.new(
        key: :match_variant,
        title: "Next action: Match variant",
        body: "Link this research demand to a sellable SKU before fulfillment.",
        kind: :anchor,
        primary_label: "Match variant",
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: "demand-match-variant"
      )
    end

    def pickup_action
      NextAction.new(
        key: :ready_for_pickup,
        title: "Next action: Customer pickup",
        body: pickup_body,
        kind: :link,
        primary_label: "Open POS pickup",
        primary_path: pos_pickup_path,
        primary_method: nil,
        primary_params: nil,
        secondary_label: customer_contact_label,
        secondary_path: customer_path,
        anchor: nil
      )
    end

    def vendor_backorder_action
      NextAction.new(
        key: :vendor_backorder,
        title: "Next action: Vendor backorder active",
        body: "#{supply_summary.vendor_backorder_quantity} #{'copy'.pluralize(supply_summary.vendor_backorder_quantity)} on vendor backorder.",
        kind: :link,
        primary_label: "Review sourcing",
        primary_path: active_sourcing_run ? sourcing_run_path(active_sourcing_run) : sourcing_root_path,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def planned_po_action
      NextAction.new(
        key: :planned_po,
        title: "Next action: Planned on order",
        body: "Draft purchase order covers this variant. Coverage is planned, not committed inbound supply until the PO is submitted.",
        kind: :link,
        primary_label: "View purchase orders",
        primary_path: orders_root_path,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def create_po_action
      NextAction.new(
        key: :create_po,
        title: "Next action: Add confirmed quantity to purchase order",
        body: vendor_confirmed_body,
        kind: :link,
        primary_label: "Create PO draft",
        primary_path: create_po_demand_demand_line_path(demand_line),
        primary_method: nil,
        primary_params: nil,
        secondary_label: "Add to existing PO",
        secondary_path: add_to_po_demand_demand_line_path(demand_line),
        anchor: nil
      )
    end

    def review_sourcing_action
      NextAction.new(
        key: :review_sourcing,
        title: "Next action: Review sourcing",
        body: sourcing_review_body,
        kind: :link,
        primary_label: "Open sourcing run",
        primary_path: sourcing_run_path(active_sourcing_run),
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def review_inbound_action
      NextAction.new(
        key: :review_inbound,
        title: "Next action: Allocate inbound stock",
        body: "#{supply_summary.inbound_available} #{'copy'.pluralize(supply_summary.inbound_available)} available on open purchase orders.",
        kind: :anchor,
        primary_label: "Review inbound options",
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: "demand-allocation-workbench"
      )
    end

    def allocate_on_hand_action
      NextAction.new(
        key: :allocate_on_hand,
        title: "Next action: Allocate on-hand stock",
        body: "#{supply_summary.on_hand_available} #{'copy'.pluralize(supply_summary.on_hand_available)} available at this store.",
        kind: :anchor,
        primary_label: "Allocate on hand",
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: "demand-allocation-workbench"
      )
    end

    def start_sourcing_action
      NextAction.new(
        key: :start_sourcing,
        title: "Next action: Start sourcing",
        body: "No available on-hand or inbound supply.",
        kind: :anchor,
        primary_label: "Start sourcing run",
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: "demand-sourcing-panel"
      )
    end

    def notify_customer_action
      NextAction.new(
        key: :notify_customer,
        title: "Next action: Contact customer",
        body: "Stock is available. Notify the customer before releasing the hold.",
        kind: :link,
        primary_label: "Contact customer",
        primary_path: customer_path,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def info_action(title, body)
      NextAction.new(
        key: :info,
        title: title,
        body: body,
        kind: :info,
        primary_label: nil,
        primary_path: nil,
        primary_method: nil,
        primary_params: nil,
        secondary_label: nil,
        secondary_path: nil,
        anchor: nil
      )
    end

    def ready_for_pickup?
      demand_line.demand_allocations.active_allocations.on_hand_kind
                 .where("expires_at IS NULL OR expires_at > ?", Time.current)
                 .exists?
    end

    def vendor_confirmed_needs_po?
      return false if latest_vendor_response.blank?

      latest_vendor_response.quantity_confirmed.positive? &&
        supply_summary.inbound_allocated_to_demand.zero? &&
        supply_summary.unallocated_quantity.positive?
    end

    def sourcing_eligible?
      sourcing_eligibility&.eligible != false && unresolved_qty.positive?
    end

    def unresolved_qty
      sourcing_unresolved || Sourcing::UnresolvedQuantity.for_demand_line(demand_line)
    end

    def pickup_body
      qty = demand_line.demand_allocations.active_allocations.on_hand_kind.sum(:quantity_allocated)
      "#{qty} #{'copy'.pluralize(qty)} allocated on hand and ready for POS pickup."
    end

    def vendor_confirmed_body
      "Vendor confirmed #{latest_vendor_response.quantity_confirmed} #{'copy'.pluralize(latest_vendor_response.quantity_confirmed)}."
    end

    def sourcing_review_body
      if latest_vendor_response.present?
        "Vendor response recorded. Review attempt outcomes and next buyer action."
      else
        "Vendor response is pending."
      end
    end

    def customer_path
      return nil if demand_line.customer.blank?

      Rails.application.routes.url_helpers.customers_customer_path(demand_line.customer)
    end

    def customer_contact_label
      demand_line.customer.present? ? "Contact customer" : nil
    end

    def pos_pickup_path
      Rails.application.routes.url_helpers.pos_root_path(pickup: demand_line.demand_number)
    end

    def sourcing_run_path(run)
      Rails.application.routes.url_helpers.sourcing_run_path(run)
    end

    def sourcing_root_path
      Rails.application.routes.url_helpers.sourcing_root_path
    end

    def orders_root_path
      Rails.application.routes.url_helpers.orders_root_path
    end

    def create_po_demand_demand_line_path(line)
      Rails.application.routes.url_helpers.create_po_demand_demand_line_path(line)
    end

    def add_to_po_demand_demand_line_path(line)
      Rails.application.routes.url_helpers.add_to_po_demand_demand_line_path(line)
    end

    def build_timeline
      events = []
      events << TimelineEvent.new(label: "Created", occurred_at: demand_line.created_at, detail: demand_line.created_by_user.display_name)
      if demand_line.matched_at.present?
        events << TimelineEvent.new(label: "Variant matched", occurred_at: demand_line.matched_at, detail: demand_line.product_variant&.sku)
      end
      demand_line.demand_allocations.order(:allocated_at).each do |allocation|
        events << TimelineEvent.new(
          label: "Allocation #{allocation.status}",
          occurred_at: allocation.allocated_at,
          detail: "#{allocation.quantity_allocated} #{allocation.allocation_kind.humanize.downcase}"
        )
      end
      demand_line.sourcing_runs.order(:started_at).each do |run|
        events << TimelineEvent.new(label: "Sourcing run #{run.status}", occurred_at: run.started_at, detail: "Run ##{run.id}")
      end
      AuditEvent.for_auditable(demand_line).limit(20).each do |audit|
        events << TimelineEvent.new(label: audit.event_name, occurred_at: audit.occurred_at, detail: nil)
      end
      events.sort_by(&:occurred_at).reverse
    end
  end
end
