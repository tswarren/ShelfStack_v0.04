# frozen_string_literal: true

module CustomerRequests
  class IndexRowPresenter
    Row = Data.define(
      :request,
      :request_number,
      :request_path,
      :customer_name,
      :contact_line,
      :primary_item,
      :status,
      :timing_label,
      :next_action,
      :available_qty,
      :assigned_name
    )

    def self.build_collection(requests, store:)
      new(requests, store:).build_collection
    end

    def initialize(requests, store:)
      @requests = Array(requests)
      @store = store
    end

    def build_collection
      context = request_context

      @requests.map do |request|
        action = NextActionResolver.for_request(
          request,
          store: store,
          active_reservations_by_line: context[:active_reservations_by_line],
          availability_by_variant: context[:availability_by_variant]
        )
        primary_line = request.customer_request_lines.min_by(&:line_number)
        variant_id = primary_line&.product_variant_id

        Row.new(
          request: request,
          request_number: request.request_number,
          request_path: Rails.application.routes.url_helpers.customers_customer_request_path(request),
          customer_name: request.display_customer_name,
          contact_line: contact_line_for(request),
          primary_item: primary_item_summary(primary_line),
          status: request.status,
          timing_label: timing_label_for(request),
          next_action: action,
          available_qty: variant_id.present? ? context[:availability_by_variant][variant_id] : nil,
          assigned_name: request.assigned_to_user&.display_name
        )
      end
    end

    private

    attr_reader :store

    def request_context
      line_ids = @requests.flat_map { |request| request.customer_request_lines.map(&:id) }
      variant_ids = @requests.flat_map do |request|
        request.customer_request_lines.filter_map(&:product_variant_id)
      end.uniq

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

    def contact_line_for(request)
      phone = request.customer&.phone || request.customer_phone_snapshot
      email = request.customer&.email || request.customer_email_snapshot
      [ phone.presence, email.presence ].compact.join(" · ").presence || "—"
    end

    def primary_item_summary(line)
      return "—" if line.blank?

      if line.product_variant.present?
        [ line.product_variant.name, line.product_variant.sku ].compact.join(" · ")
      else
        [ line.provisional_title, line.provisional_identifier ].compact.join(" · ").presence || "—"
      end
    end

    def timing_label_for(request)
      if request.needed_by_date.present?
        "Needed #{I18n.l(request.needed_by_date)}"
      else
        "#{((Time.current - request.created_at) / 1.day).floor}d old"
      end
    end
  end
end
