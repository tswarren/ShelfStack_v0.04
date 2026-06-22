# frozen_string_literal: true

module Customers
  class DashboardPresenter
    PreviewRow = Data.define(:request_number, :customer_name, :primary_item, :next_action_label, :request_path, :urgency_label)
    QueueCard = Data.define(:key, :label, :count, :path, :preview_rows)

    def initialize(store:)
      @store = store
      @queue_counts = CustomerRequests::QueueScope.counts_for(store: store)
    end

    attr_reader :queue_counts

    def open_request_count
      CustomerRequest.where(store: store).open_requests.count
    end

    def metrics
      [ { label: "Open requests", value: open_request_count } ]
    end

    def queue_cards
      CustomerRequests::QueueScope::OPERATIONAL_QUEUE_KEYS.map do |queue_key|
        QueueCard.new(
          key: queue_key,
          label: CustomersHelper::QUEUE_LABELS.fetch(queue_key),
          count: queue_counts.fetch(queue_key, 0),
          path: queue_path(queue_key),
          preview_rows: preview_rows_for(queue_key)
        )
      end
    end

    private

    attr_reader :store

    def queue_path(queue_key)
      Rails.application.routes.url_helpers.customers_customer_requests_path(queue: queue_key)
    end

    def preview_rows_for(queue_key)
      requests = preview_requests_for(queue_key)
      context = request_context(requests)

      requests.map do |request|
        action = CustomerRequests::NextActionResolver.for_request(
          request,
          store: store,
          active_reservations_by_line: context[:active_reservations_by_line],
          availability_by_variant: context[:availability_by_variant]
        )
        PreviewRow.new(
          request_number: request.request_number,
          customer_name: request.display_customer_name,
          primary_item: primary_item_summary(request),
          next_action_label: action.label,
          request_path: action.path,
          urgency_label: urgency_label_for(request, queue_key)
        )
      end
    end

    def preview_requests_for(queue_key)
      relation = CustomerRequests::QueueScope.apply(
        CustomerRequest.where(store: store),
        queue_key,
        store: store
      )

      includes = [
        :customer,
        customer_request_lines: [ :product_variant, :special_order, { inventory_reservations: [] } ]
      ]

      if queue_key == "expiring_holds"
        request_ids = CustomerRequest.where(store: store)
                                     .joins(customer_request_lines: :inventory_reservations)
                                     .where(
                                       inventory_reservations: {
                                         reservation_type: "on_hand_hold",
                                         status: %w[active ready]
                                       }
                                     )
                                     .where(inventory_reservations: { expires_at: ..CustomerRequests::QueueScope::EXPIRING_HOLD_WINDOW.from_now })
                                     .group("customer_requests.id")
                                     .order(Arel.sql("MIN(inventory_reservations.expires_at) ASC"))
                                     .limit(3)
                                     .pluck(:id)
        requests_by_id = CustomerRequest.where(id: request_ids).includes(includes).index_by(&:id)
        return request_ids.filter_map { |id| requests_by_id[id] }
      end

      relation.includes(includes)
              .order(Arel.sql("customer_requests.needed_by_date ASC NULLS LAST"), "customer_requests.created_at ASC")
              .distinct
              .limit(3)
              .to_a
    end

    def request_context(requests)
      line_ids = requests.flat_map { |request| request.customer_request_lines.map(&:id) }
      variant_ids = requests.flat_map { |request| request.customer_request_lines.filter_map(&:product_variant_id) }.uniq

      active_reservations = if line_ids.any?
        CustomerRequests::ReservationLookup.active_by_line_id(line_ids)
      else
        {}
      end

      availability_by_variant = variant_ids.index_with do |variant_id|
        variant = ProductVariant.find(variant_id)
        Inventory::Availability.available(store: store, variant: variant)
      end

      { active_reservations_by_line: active_reservations, availability_by_variant: availability_by_variant }
    end

    def primary_item_summary(request)
      line = request.customer_request_lines.min_by(&:line_number)
      return "—" if line.blank?

      if line.product_variant.present?
        line.product_variant.name.presence || line.product_variant.sku
      else
        line.provisional_title.presence || line.provisional_identifier.presence || "—"
      end
    end

    def urgency_label_for(request, queue_key)
      if queue_key == "expiring_holds"
        hold = request.customer_request_lines.flat_map(&:inventory_reservations)
                      .select { |reservation|
                        reservation.reservation_type == "on_hand_hold" &&
                          %w[active ready].include?(reservation.status) &&
                          reservation.expires_at.present?
                      }
                      .min_by(&:expires_at)
        return "Expires #{I18n.l(hold.expires_at.to_date)}" if hold.present?
      end

      if request.needed_by_date.present?
        "Needed by #{I18n.l(request.needed_by_date)}"
      else
        "#{((Time.current - request.created_at) / 1.day).floor}d old"
      end
    end
  end
end
