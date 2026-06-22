# frozen_string_literal: true

module CustomerRequests
  class LineShowPresenter
    TrailStep = Data.define(:label, :state)
    Availability = Data.define(:available, :on_hand, :reserved)

    def self.build(line:, store:, active_hold: nil, availability: nil, draft_po_lines: [], vendors: [])
      new(line:, store:, active_hold:, availability:, draft_po_lines:, vendors:).build
    end

    def initialize(line:, store:, active_hold: nil, availability: nil, draft_po_lines: [], vendors: [])
      @line = line
      @store = store
      @active_hold = active_hold
      @availability = availability
      @draft_po_lines = draft_po_lines
      @vendors = vendors
    end

    attr_reader :line, :active_hold, :availability, :draft_po_lines, :vendors

    def build
      self
    end

    def customer_request
      line.customer_request
    end

    def next_action
      NextActionResolver.for_line(
        line,
        store: store,
        customer_request: customer_request,
        active_hold: active_hold,
        availability: availability_hash
      )
    end

    def contact_relevant?
      line.status == "awaiting_customer_response" ||
        line.status == "ready_for_pickup" ||
        notify_ready?
    end

    def item_title
      if line.product_variant.present?
        line.product_variant.name.presence || line.product_variant.sku
      else
        line.provisional_title.presence || "Unmatched item"
      end
    end

    def item_subtitle
      if line.product_variant.present?
        line.product_variant.sku
      else
        line.provisional_identifier
      end
    end

    def availability_summary
      return nil if availability_hash.blank?

      Availability.new(
        available: availability_hash[:available].to_i,
        on_hand: availability_hash[:on_hand].to_i,
        reserved: availability_hash[:on_hand].to_i - availability_hash[:available].to_i
      )
    end

    def trail_steps
      steps = [ trail_step("Requested", requested_state) ]
      if line.matched?
        steps << trail_step("Matched", matched_state)
      elsif line.status == "researching" || line.status == "new"
        steps << trail_step("Researching", current_state_for("researching"))
      end

      case line.request_type
      when "notify"
        steps << trail_step("Notify", notify_state)
      when "hold"
        steps << trail_step("Hold", hold_state)
      when "special_order"
        steps << trail_step("Special order", special_order_state)
        steps << trail_step("Ordered", ordered_state) if ordered_relevant?
      end

      steps << trail_step("Ready", ready_state) if ready_relevant?
      steps << trail_step("Completed", completed_state) if line.status == "completed"
      steps << trail_step("Closed", current_state_for("cancelled")) if %w[cancelled unfillable].include?(line.status)
      steps.uniq { |step| step.label }
    end

    def quantity_summary
      parts = [ "Requested #{line.requested_quantity}" ]
      parts << "filled #{line.filled_quantity}" if line.filled_quantity.positive?
      parts << "cancelled #{line.cancelled_quantity}" if line.cancelled_quantity.positive?
      parts.join(" · ")
    end

    def hold_expires_on
      active_hold&.expires_at&.to_date
    end

    def can_create_hold?
      line.matched? && %w[hold notify].include?(line.request_type) && active_hold.blank?
    end

    def can_override_hold?
      availability_summary.present? && line.requested_quantity > availability_summary.available
    end

    private

    attr_reader :store

    def availability_hash
      @availability
    end

    def notify_ready?
      line.request_type == "notify" && line.matched? && NotifyQueueQuery.qualifies?(line, store: store)
    end

    def trail_step(label, state)
      TrailStep.new(label: label, state: state)
    end

    def requested_state
      line.status == "new" ? "current" : "complete"
    end

    def matched_state
      return "current" if line.status == "matched"
      return "complete" if line.matched?

      "upcoming"
    end

    def notify_state
      return "current" if line.request_type == "notify" && %w[matched awaiting_customer_response].include?(line.status)
      return "complete" if line.request_type == "notify" && line.matched?

      "upcoming"
    end

    def hold_state
      return "current" if active_hold.present?
      return "complete" if %w[ready_for_pickup partially_filled completed].include?(line.status)

      line.request_type == "hold" && line.matched? ? "upcoming" : "upcoming"
    end

    def special_order_state
      return "current" if line.special_order.present? && %w[pending_match approved].include?(line.special_order.status)
      return "complete" if line.special_order.present?

      line.request_type == "special_order" && line.matched? ? "upcoming" : "upcoming"
    end

    def ordered_state
      return "current" if %w[ordered partially_filled].include?(line.status)
      return "complete" if line.ordered_quantity.positive?

      "upcoming"
    end

    def ready_state
      return "current" if line.status == "ready_for_pickup"
      return "complete" if line.status == "completed"

      "upcoming"
    end

    def completed_state
      line.status == "completed" ? "current" : "upcoming"
    end

    def current_state_for(status)
      line.status == status ? "current" : "upcoming"
    end

    def ordered_relevant?
      line.request_type == "special_order" &&
        (line.ordered_quantity.positive? || %w[ordered partially_filled ready_for_pickup completed].include?(line.status))
    end

    def ready_relevant?
      %w[ready_for_pickup partially_filled completed].include?(line.status) ||
        (line.request_type == "hold" && active_hold.present?)
    end
  end
end
