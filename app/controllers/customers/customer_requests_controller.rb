# frozen_string_literal: true

module Customers
  class CustomerRequestsController < BaseController
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
      @queue_counts = CustomerRequests::QueueScope.counts_for(store: customers_store)
      @customer_requests = CustomerRequest.includes(:customer, :assigned_to_user, customer_request_lines: :product_variant)
                                          .where(store: customers_store)
                                          .order(created_at: :desc)

      @customer_requests = CustomerRequests::QueueScope.apply(@customer_requests, @queue, store: customers_store) if @queue.present?
      @customer_requests = CustomerRequests::SearchQuery.apply(@customer_requests, params[:q])
      @index_rows = CustomerRequests::IndexRowPresenter.build_collection(@customer_requests, store: customers_store)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@customer_request).limit(50)
      @contact_events = CustomerContactEvent.where(customer_request: @customer_request).order(occurred_at: :desc)
      @show_presenter = CustomerRequests::ShowPresenter.new(
        customer_request: @customer_request,
        store: customers_store,
        contact_events: @contact_events,
        audit_events: @audit_events
      )
    end

    def new
      @customer_request = CustomerRequest.new(store: customers_store, source: "in_store", created_by_user: current_user)
      @customer_request.customer_request_lines.build(line_number: 1, request_type: "research", requested_quantity: 1)
      apply_selected_customer!(@customer_request)
      load_form_collections
    end

    def create
      @customer_request = CustomerRequests::CreateFromForm.call!(
        store: customers_store,
        created_by_user: current_user,
        params: params
      )
      redirect_to customers_customer_request_path(@customer_request), notice: "Customer request created."
    rescue CustomerRequests::CreateFromForm::CreateError => e
      @customer_request = CustomerRequest.new(customer_request_params)
      @customer_request.store = customers_store
      @customer_request.created_by_user = current_user
      @customer_request.errors.add(:base, e.message)
      load_form_collections
      render :new, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      @customer_request = e.record
      load_form_collections
      render :new, status: :unprocessable_entity
    end

    def edit
      @selected_customer = @customer_request.customer
      load_form_collections
    end

    def update
      if @customer_request.update(customer_request_params)
        @customer_request.refresh_status_from_lines!(actor: current_user, source: @customer_request)
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
      CustomerRequests::ChangeLineType.call!(
        request: @customer_request,
        line: line,
        request_type: params[:request_type],
        actor: current_user
      )
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Line type updated to #{params[:request_type].to_s.tr('_', ' ')}."
    rescue CustomerRequests::ChangeLineType::ChangeError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    end

    def mark_awaiting_response
      line = @customer_request.customer_request_lines.find(params[:line_id])
      CustomerRequests::MarkAwaitingResponse.call!(
        request: @customer_request,
        line: line,
        actor: current_user
      )
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Line marked awaiting customer response."
    end

    def create_hold
      line = @customer_request.customer_request_lines.find(params[:line_id])
      override_user = if params[:override_reason].present? &&
                         Authorization.allowed?(user: current_user, permission_key: "inventory_reservations.override", store: current_store)
                        current_user
      end

      CustomerRequests::CreateHoldFromLine.call!(
        request: @customer_request,
        line: line,
        store: customers_store,
        actor: current_user,
        quantity: params[:quantity],
        expires_at: params[:expires_at],
        override_authorized_by_user: override_user,
        override_reason: params[:override_reason]
      )
      redirect_to customers_customer_request_path(@customer_request, anchor: "line-#{line.id}"),
                  notice: "Hold created."
    rescue CustomerRequests::CreateHoldFromLine::HoldError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
    rescue StandardError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
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

    def release_hold
      reservation = InventoryReservation.find(params[:reservation_id])
      raise StandardError, "Reservation does not belong to this request" unless reservation.customer_request_line&.customer_request_id == @customer_request.id
      raise StandardError, "Only on-hand holds can be released from the request screen" unless reservation.reservation_type == "on_hand_hold"

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
      CustomerRequests::RecordContact.call!(
        actor: current_user,
        customer_request: @customer_request,
        customer_request_line_id: params[:line_id],
        contact_method: params[:contact_method],
        direction: params[:direction] || "outbound",
        status: params[:status] || "attempted",
        summary: params[:summary]
      )
      redirect_to customers_customer_request_path(@customer_request), notice: "Contact recorded."
    rescue CustomerRequests::RecordContact::RecordError => e
      redirect_to customers_customer_request_path(@customer_request), alert: e.message
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
