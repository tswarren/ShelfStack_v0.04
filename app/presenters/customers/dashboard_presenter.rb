# frozen_string_literal: true

module Customers
  class DashboardPresenter
    PreviewRow = Data.define(:demand_number, :customer_name, :primary_item, :next_action_label, :demand_path, :urgency_label)
    QueueCard = Data.define(:key, :label, :count, :path, :preview_rows)

    def initialize(store:)
      @store = store
      @queue_counts = show_counts
    end

    attr_reader :queue_counts

    def open_demand_count
      DemandLine.where(store: store).where.not(status: DemandLine::TERMINAL_STATUSES).count
    end

    def metrics
      [ { label: "Open demand", value: open_demand_count } ]
    end

    def queue_cards
      DemandLines::QueueScope::OPERATIONAL_QUEUE_KEYS.map do |queue_key|
        QueueCard.new(
          key: queue_key,
          label: customers_demand_queue_label(queue_key),
          count: queue_counts.fetch(queue_key, 0),
          path: queue_path(queue_key),
          preview_rows: preview_rows_for(queue_key)
        )
      end
    end

    private

    attr_reader :store

    def show_counts
      DemandLines::QueueScope::OPERATIONAL_QUEUE_KEYS.index_with do |key|
        DemandLines::QueueScope.count(store: store, queue_key: key)
      end
    end

    def customers_demand_queue_label(queue_key)
      ::DemandLines::QueueScope::QUEUE_LABELS.fetch(queue_key, queue_key.to_s.humanize)
    end

    def queue_path(queue_key)
      Rails.application.routes.url_helpers.demand_demand_lines_path(queue: queue_key)
    end

    def preview_rows_for(queue_key)
      demand_lines = preview_demand_lines_for(queue_key)

      demand_lines.map do |demand_line|
        PreviewRow.new(
          demand_number: demand_line.demand_number,
          customer_name: demand_line.display_customer_name,
          primary_item: primary_item_summary(demand_line),
          next_action_label: next_action_label_for(demand_line, queue_key),
          demand_path: Rails.application.routes.url_helpers.demand_demand_line_path(demand_line),
          urgency_label: urgency_label_for(demand_line, queue_key)
        )
      end
    end

    def preview_demand_lines_for(queue_key)
      relation = DemandLines::QueueScope.apply(
        DemandLine.where(store: store),
        queue_key,
        store: store
      )

      includes = [ :customer, :product_variant, { demand_allocations: [] } ]

      if queue_key == "expiring_holds"
        lines = relation.includes(includes).distinct.limit(20).to_a
        return lines.sort_by { |demand_line| earliest_allocation_expiry(demand_line) || 100.years.from_now }.first(3)
      end

      relation.includes(includes)
              .order(Arel.sql("demand_lines.needed_by_date ASC NULLS LAST"), "demand_lines.created_at ASC")
              .distinct
              .limit(3)
              .to_a
    end

    def primary_item_summary(demand_line)
      if demand_line.product_variant.present?
        demand_line.product_variant.name.presence || demand_line.product_variant.sku
      else
        demand_line.provisional_title.presence || demand_line.provisional_identifier.presence || "—"
      end
    end

    def next_action_label_for(demand_line, queue_key)
      case queue_key
      when "ready_for_pickup", "expiring_holds"
        "POS pickup"
      when "notify_customer"
        "Contact customer"
      when "needs_research"
        "Match variant"
      when "approved_to_order"
        "Start sourcing"
      when "on_order", "vendor_backorder"
        "View demand"
      when "awaiting_response"
        "Review sourcing"
      else
        "View demand"
      end
    end

    def earliest_allocation_expiry(demand_line)
      demand_line.demand_allocations
                 .select { |allocation| allocation.on_hand? && allocation.active? && allocation.expires_at.present? }
                 .min_by(&:expires_at)
                 &.expires_at
    end

    def urgency_label_for(demand_line, queue_key)
      if queue_key == "expiring_holds"
        hold = demand_line.demand_allocations
                          .select { |allocation|
                            allocation.on_hand? && allocation.active? && allocation.expires_at.present?
                          }
                          .min_by(&:expires_at)
        return "Expires #{I18n.l(hold.expires_at.to_date)}" if hold.present?
      end

      if demand_line.needed_by_date.present?
        "Needed by #{I18n.l(demand_line.needed_by_date)}"
      else
        "#{((Time.current - demand_line.created_at) / 1.day).floor}d old"
      end
    end
  end
end
