# frozen_string_literal: true

module CustomerRequests
  class QueueScope
    EXPIRING_HOLD_WINDOW = 3.days

    QUEUE_FILTERS = {
      "new" => { status: "new" },
      "needs_research" => { kind: :needs_research },
      "awaiting_response" => { status: "awaiting_customer_response" },
      "approved_to_order" => { kind: :approved_to_order },
      "on_order" => { status: %w[ordered partially_filled] },
      "ready_for_pickup" => { kind: :ready_for_pickup },
      "notify_customer" => { kind: :notify_customer },
      "expiring_holds" => { kind: :expiring_holds },
      "completed" => { status: "completed" },
      "cancelled" => { status: "cancelled" },
      "unfillable" => { status: "unfillable" }
    }.freeze

    OPERATIONAL_QUEUE_KEYS = %w[
      ready_for_pickup notify_customer needs_research awaiting_response approved_to_order expiring_holds
    ].freeze

    QUEUE_KEYS = QUEUE_FILTERS.keys.freeze

    def self.apply(relation, queue_key, store:)
      new(relation, queue_key, store:).apply
    end

    def self.count(store:, queue_key:)
      apply(CustomerRequest.where(store: store), queue_key, store: store).distinct.count
    end

    def self.counts_for(store:)
      QUEUE_KEYS.index_with { |key| count(store: store, queue_key: key) }
    end

    def self.base_relation(store:)
      CustomerRequest.where(store: store)
    end

    def initialize(relation, queue_key, store:)
      @relation = relation
      @queue_key = queue_key.to_s
      @store = store
    end

    def apply
      filter = QUEUE_FILTERS[@queue_key]
      return @relation if filter.blank?

      case filter[:kind]
      when :needs_research
        apply_needs_research
      when :approved_to_order
        apply_approved_to_order
      when :notify_customer
        apply_notify_customer
      when :expiring_holds
        apply_expiring_holds
      when :ready_for_pickup
        apply_ready_for_pickup
      else
        apply_status(filter)
      end
    end

    private

    attr_reader :store

    def apply_needs_research
      @relation.joins(:customer_request_lines)
               .merge(CustomerRequestLine.open_lines.where(product_variant_id: nil))
               .distinct
    end

    def apply_approved_to_order
      @relation.joins(customer_request_lines: :special_order)
               .where(special_orders: { status: "approved" })
               .distinct
    end

    def apply_notify_customer
      ids = NotifyQueueQuery.customer_request_ids_for(store: store)
      @relation.where(id: ids)
    end

    def apply_ready_for_pickup
      line_ready_ids = @relation.joins(:customer_request_lines)
                                  .merge(CustomerRequestLine.open_lines.where(status: "ready_for_pickup"))
                                  .select(:id)
      reservation_ready_ids = @relation.joins(customer_request_lines: :inventory_reservations)
                                         .merge(InventoryReservation.active_on_hand.where(status: %w[active ready]))
                                         .select(:id)

      @relation.where(id: line_ready_ids).or(@relation.where(id: reservation_ready_ids)).distinct
    end

    def apply_expiring_holds
      @relation.joins(customer_request_lines: :inventory_reservations)
               .where(
                 inventory_reservations: {
                   reservation_type: "on_hand_hold",
                   status: %w[active ready]
                 }
               )
               .where(inventory_reservations: { expires_at: ..EXPIRING_HOLD_WINDOW.from_now })
               .distinct
    end

    def apply_status(filter)
      if filter[:status].is_a?(Array)
        @relation.where(status: filter[:status])
      elsif filter[:line_type]
        @relation.joins(:customer_request_lines)
                   .where(customer_request_lines: {
                     request_type: filter[:line_type],
                     status: filter[:line_status]
                   }).distinct
      else
        @relation.where(status: filter[:status])
      end
    end
  end
end
