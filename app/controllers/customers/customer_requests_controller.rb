# frozen_string_literal: true

module Customers
  class CustomerRequestsController < BaseController
    QUEUE_FILTERS = {
      "new" => { status: "new" },
      "needs_research" => { kind: :needs_research },
      "awaiting_response" => { status: "awaiting_customer_response" },
      "approved_to_order" => { kind: :approved_to_order },
      "on_order" => { status: %w[ordered partially_filled] },
      "ready_for_pickup" => { status: "ready_for_pickup" },
      "notify_customer" => { kind: :notify_customer },
      "expiring_holds" => { kind: :expiring_holds },
      "completed" => { status: "completed" },
      "cancelled" => { status: "cancelled" },
      "unfillable" => { status: "unfillable" }
    }.freeze

    EXPIRING_HOLD_WINDOW = 3.days

    before_action :set_customer_request, only: %i[
      show edit update cancel mark_unfillable match_variant create_special_order
      create_hold release_hold update_line_type mark_awaiting_response
      attach_special_order build_purchase_order_from_special_order record_contact
    ]
    before_action -> { authorize!("customer_requests.access") }, only: %i[index show]
    before_action -> { authorize!("customer_requests.create") }, only: %i[new create]
    before_action -> { authorize!("customer_requests.update") }, only: %i[edit update match_variant update_line_type mark_awaiting_response]
    before_action -> { authorize!("customer_requests.cancel") }, only: :cancel
    before_action -> { authorize!("customer_requests.mark_unfillable") }, only: :mark_unfillable
    before_action -> { authorize!("customer_requests.contact") }, only: :record_contact
    before_action -> { authorize!("special_orders.create") }, only: %i[create_special_order build_purchase_order_from_special_order]
    before_action -> { authorize!("special_orders.attach_to_po") }, only: :attach_special_order
    before_action -> { authorize!("inventory_reservations.create") }, only: :create_hold
    before_action -> { authorize!("inventory_reservations.release") }, only: :release_hold

    def index
      @queue = params[:queue]
      @customer_requests = CustomerRequest.includes(:customer, :customer_request_lines)
                                          .where(store: customers_store)
                                          .order(created_at: :desc)

      apply_queue_filter! if @queue.present?
      @customer_requests = @customer_requests.where("request_number ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    end

    def show
      @audit_events = AuditEvent.for_auditable(@customer_request).limit(50)
      @contact_events = CustomerContactEvent.where(customer_request: @customer_request).order(occurred_at: :desc)
      load_show_presenters!
    end

    def new
      @customer_request = CustomerRequest.new(store: customers_store, source: "in_store", created_by_user: current_user)
      @customer_request.customer_request_lines.build(line_number: 1, request_type: "research", requested_quantity: 1)
      apply_selected_customer!(@customer_request)
      load_form_collections
    end

    def create
      @customer_request = CustomerRequest.new(customer_request_params)
      @customer_request.store = customers_store
      @customer_request.created_by_user = current_user
      @customer_request.status = "new"
      @customer_request.request_number = CustomerRequests::RequestNumberAssigner.next_for!(store: customers_store)

      if @customer_request.save
        AuditEvents.record!(
          actor: current_user,
          event_name: "customer_request.created",
          auditable: @customer_request,
          details: {
            "request_number" => @customer_request.request_number,
            "line_count" => @customer_request.customer_request_lines.size
          }
        )
        redirect_to customers_customer_request_path(@customer_request), notice: "Customer request created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @selected_customer = @customer_request.customer
      load_form_collections
    end

    def update
      if @customer_request.update(customer_request_params)
        @customer_request.refresh_status_from_lines!
        record_audit!("customer_request.updated", @customer_request)
        redirect_to customers_customer_request_path(@customer_request), notice: "Customer request updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def cancel
      CustomerRequests::Cancel.call!(request: @customer_request, actor: current_user, reason: params[:reason])
      redirect_to customers_customer_requests_path, notice: "Customer request cancelled."
    rescue CustomerRequests::Cancel::CancelError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def mark_unfillable
      CustomerRequests::MarkUnfillable.call!(request: @customer_request, actor: current_user, reason: params[:reason])
      redirect_to customers_customer_request_path(@customer_request), notice: "Customer request marked unfillable."
    rescue CustomerRequests::MarkUnfillable::MarkUnfillableError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def match_variant
      line = find_match_line!
      variant = ProductVariant.find(params[:product_variant_id])
      CustomerRequests::MatchVariant.call!(line: line, variant: variant, actor: current_user)
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Line matched to #{variant.sku}."
    rescue CustomerRequests::MatchVariant::MatchError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def update_line_type
      line = @customer_request.customer_request_lines.find(params[:line_id])
      request_type = params[:request_type].to_s
      unless CustomerRequestLine::REQUEST_TYPES.include?(request_type)
        raise StandardError, "Invalid request type"
      end

      line.update!(request_type: request_type)
      @customer_request.refresh_status_from_lines!
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Line type updated to #{request_type.tr('_', ' ')}."
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def mark_awaiting_response
      line = @customer_request.customer_request_lines.find(params[:line_id])
      line.update!(status: "awaiting_customer_response")
      @customer_request.refresh_status_from_lines!
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Line marked awaiting customer response."
    end

    def create_special_order
      line = @customer_request.customer_request_lines.find(params[:line_id])
      special_order = SpecialOrders::CreateFromRequestLine.call!(line: line, created_by_user: current_user)
      SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: current_user)
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Special order created and approved."
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def create_hold
      line = @customer_request.customer_request_lines.find(params[:line_id])
      raise StandardError, "Line must be matched" unless line.matched?

      quantity = params[:quantity].presence&.to_i || line.requested_quantity
      expires_at = params[:expires_at].present? ? Time.zone.parse(params[:expires_at]) : nil
      override_user = if params[:override_reason].present? &&
                         Authorization.allowed?(user: current_user, permission_key: "inventory_reservations.override", store: current_store)
                        current_user
      end

      InventoryReservations::ReserveOnHand.call!(
        store: customers_store,
        variant: line.product_variant,
        quantity: quantity,
        reserved_by_user: current_user,
        customer: @customer_request.customer,
        customer_request_line: line,
        expires_at: expires_at,
        override_authorized_by_user: override_user,
        override_reason: params[:override_reason]
      )
      line.update!(status: "ready_for_pickup")
      @customer_request.refresh_status_from_lines!
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Hold created."
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def release_hold
      reservation = InventoryReservation.find(params[:reservation_id])
      raise StandardError, "Reservation does not belong to this request" unless reservation.customer_request_line&.customer_request_id == @customer_request.id

      InventoryReservations::Release.call!(
        reservation: reservation,
        released_by_user: current_user,
        release_reason: params[:release_reason].presence || "staff_release"
      )
      redirect_to customers_customer_request_path(@customer_request), notice: "Hold released."
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def attach_special_order
      special_order = SpecialOrder.find(params[:special_order_id])
      raise StandardError, "Special order does not belong to this request" unless special_order.customer_request_line.customer_request_id == @customer_request.id

      po_line = PurchaseOrderLine.joins(:purchase_order)
                                 .where(purchase_orders: { store_id: customers_store.id, status: "draft" })
                                 .find(params[:purchase_order_line_id])
      quantity = params[:quantity].presence&.to_i || special_order.remaining_committed

      SpecialOrders::AttachToPurchaseOrderLine.call!(
        special_order: special_order,
        purchase_order_line: po_line,
        quantity: quantity,
        attached_by_user: current_user
      )
      redirect_to customers_customer_request_path(@customer_request), notice: "Special order attached to purchase order."
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def build_purchase_order_from_special_order
      special_order = SpecialOrder.find(params[:special_order_id])
      vendor = Vendor.find(params[:vendor_id])
      purchase_order = Purchasing::BuildPurchaseOrder.call(
        store: customers_store,
        vendor: vendor,
        created_by_user: current_user,
        special_orders: [ special_order ]
      )
      redirect_to orders_purchase_order_path(purchase_order), notice: "Draft purchase order created from special order."
    rescue Purchasing::BuildPurchaseOrder::BuildError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def record_contact
      event = CustomerContactEvent.create!(
        customer: @customer_request.customer,
        customer_request: @customer_request,
        customer_request_line_id: params[:line_id],
        contact_method: params[:contact_method],
        direction: params[:direction] || "outbound",
        status: params[:status] || "attempted",
        summary: params[:summary],
        recorded_by_user: current_user,
        occurred_at: Time.current
      )
      @customer_request.update!(last_contacted_at: Time.current)
      record_audit!("customer_contact_event.created", event)
      redirect_to customers_customer_request_path(@customer_request), notice: "Contact recorded."
    end

    private

    def set_customer_request
      @customer_request = CustomerRequest.where(store: customers_store)
                                         .includes(customer_request_lines: [ :product_variant, :special_order, :inventory_reservations ])
                                         .find(params[:id])
    end

    def find_match_line!
      line = @customer_request.customer_request_lines.find(params[:line_id])
      context = Customers::RequestMatchContext.new(
        return_to: Customers::RequestMatchContext::RETURN_TO,
        customer_request_id: @customer_request.id,
        line_id: line.id,
        store: customers_store
      )
      raise CustomerRequests::MatchVariant::MatchError, "Invalid match context" unless context.valid?

      line
    end

    def load_show_presenters!
      lines = @customer_request.customer_request_lines
      variant_ids = lines.filter_map(&:product_variant_id)

      @active_holds_by_line = InventoryReservation.active_on_hand
                                                    .where(customer_request_line_id: lines.map(&:id))
                                                    .index_by(&:customer_request_line_id)

      @availability_by_variant = variant_ids.index_with do |variant_id|
        variant = ProductVariant.find(variant_id)
        {
          available: Inventory::Availability.available(store: customers_store, variant: variant),
          on_hand: Inventory::Availability.on_hand(store: customers_store, variant: variant)
        }
      end

      @draft_po_lines_by_variant = if variant_ids.any?
        PurchaseOrderLine.joins(:purchase_order)
                         .includes(:purchase_order, :vendor)
                         .where(
                           product_variant_id: variant_ids,
                           purchase_orders: { store_id: customers_store.id, status: "draft" }
                         )
                         .group_by(&:product_variant_id)
      else
        {}
      end

      @vendors = Vendor.active_records.order(:name)
      @show_metrics = [
        { label: "Lines", value: lines.size },
        { label: "Unmatched", value: lines.count { |line| line.product_variant_id.blank? } },
        { label: "Ready", value: lines.count { |line| line.status == "ready_for_pickup" } }
      ]

      @attention_items = build_attention_items(lines)
    end

    def build_attention_items(lines)
      items = []
      unmatched = lines.count { |line| line.product_variant_id.blank? }
      if unmatched.positive?
        items << Purchasing::DocumentAttention::AttentionItem.new(
          message: "#{unmatched} line(s) still need a variant match.",
          link_path: nil,
          link_label: nil
        )
      end

      approved_count = lines.count { |line| line.special_order&.status == "approved" }
      if approved_count.positive?
        items << Purchasing::DocumentAttention::AttentionItem.new(
          message: "#{approved_count} approved special order(s) need PO attachment.",
          link_path: nil,
          link_label: nil
        )
      end
      items
    end

    def apply_queue_filter!
      filter = QUEUE_FILTERS[@queue]
      return if filter.blank?

      case filter[:kind]
      when :needs_research
        apply_needs_research_filter!
      when :approved_to_order
        apply_approved_to_order_filter!
      when :notify_customer
        apply_notify_customer_filter!
      when :expiring_holds
        apply_expiring_holds_filter!
      else
        apply_status_filter!(filter)
      end
    end

    def apply_needs_research_filter!
      @customer_requests = @customer_requests.joins(:customer_request_lines)
                                             .merge(CustomerRequestLine.open_lines.where(product_variant_id: nil))
                                             .distinct
    end

    def apply_approved_to_order_filter!
      @customer_requests = @customer_requests.joins(customer_request_lines: :special_order)
                                             .where(special_orders: { status: "approved" })
                                             .distinct
    end

    def apply_notify_customer_filter!
      ids = CustomerRequests::NotifyQueueQuery.customer_request_ids_for(store: customers_store)
      @customer_requests = @customer_requests.where(id: ids)
    end

    def apply_expiring_holds_filter!
      @customer_requests = @customer_requests.joins(customer_request_lines: :inventory_reservations)
                                             .where(
                                               inventory_reservations: {
                                                 reservation_type: "on_hand_hold",
                                                 status: %w[active ready]
                                               }
                                             )
                                             .where(inventory_reservations: { expires_at: ..EXPIRING_HOLD_WINDOW.from_now })
                                             .distinct
    end

    def apply_status_filter!(filter)
      if filter[:status].is_a?(Array)
        @customer_requests = @customer_requests.where(status: filter[:status])
      elsif filter[:line_type]
        @customer_requests = @customer_requests.joins(:customer_request_lines)
                                               .where(customer_request_lines: {
                                                 request_type: filter[:line_type],
                                                 status: filter[:line_status]
                                               }).distinct
      else
        @customer_requests = @customer_requests.where(status: filter[:status])
      end
    end

    def load_form_collections
      @request_types = CustomerRequestLine::REQUEST_TYPES
      @sources = CustomerRequest::SOURCES
    end

    def apply_selected_customer!(request)
      return if params[:customer_id].blank?

      customer = Customer.active_records.find_by(id: params[:customer_id])
      request.customer = customer if customer
    end

    def customer_request_params
      params.require(:customer_request).permit(
        :customer_id, :source, :preferred_contact_method, :needed_by_date, :notes,
        :customer_name_snapshot, :customer_email_snapshot, :customer_phone_snapshot,
        :assigned_to_user_id,
        customer_request_lines_attributes: %i[
          id line_number request_type requested_quantity provisional_title provisional_creator
          provisional_identifier provisional_format notes status _destroy
        ]
      )
    end
  end
end
