# frozen_string_literal: true

module Demand
  class DemandLinesController < BaseController
    before_action -> { authorize_demand!("demand.create") }, only: %i[new create]
    before_action -> { authorize_demand!("demand.cancel") }, only: :cancel
    before_action -> { authorize_demand!("demand.expire") }, only: :expire
    before_action -> { authorize_demand!("demand.match_variant") }, only: :match_variant
    before_action :set_demand_line, only: %i[show cancel expire match_variant]

    def index
      @demand_lines = DemandLine.includes(:customer, :product_variant, :created_by_user)
                                .where(store: demand_store)
                                .order(created_at: :desc)
      @demand_lines = @demand_lines.where(status: params[:status]) if params[:status].present?
      @demand_lines = @demand_lines.where(source: params[:source]) if params[:source].present?
      @demand_lines = @demand_lines.where(purpose: params[:purpose]) if params[:purpose].present?
      @demand_lines = @demand_lines.where(capture_intent: params[:capture_intent]) if params[:capture_intent].present?
      apply_allocation_filters!
      apply_queue_filter!
      if params[:customer_id].present?
        @demand_lines = @demand_lines.where(customer_id: params[:customer_id])
      end
      if params[:q].present?
        q = "%#{params[:q]}%"
        @demand_lines = @demand_lines.left_joins(:product_variant, :customer).where(
          "demand_lines.demand_number ILIKE :q OR demand_lines.provisional_title ILIKE :q OR " \
          "demand_lines.customer_name_snapshot ILIKE :q OR product_variants.sku ILIKE :q OR " \
          "product_variants.name ILIKE :q OR customers.display_name ILIKE :q",
          q: q
        )
      end
    end

    def show
      @audit_events = AuditEvent.for_auditable(@demand_line).limit(50)
      @allocations = @demand_line.demand_allocations.order(allocated_at: :desc)
      @allocation_quantities = DemandAllocations::AllocationQuantities.for_demand_line(@demand_line)
      load_sourcing_context!
      if @demand_line.product_variant.present?
        @available_for_allocation = DemandAllocations::Availability.available_for_allocation(
          store: demand_store,
          variant: @demand_line.product_variant
        )
      end
    end

    def new
      @demand_line = DemandLine.new(store: demand_store, quantity_requested: 1)
      @selected_customer = resolve_customer(id: params[:customer_id], required: false)
      load_form_collections
    end

    def create
      variant = resolve_variant(id: params[:product_variant_id], required: false)
      customer = resolve_customer(id: params[:customer_id], required: false)
      capture_intent = params[:capture_intent].to_s

      @demand_line = if capture_intent == "research"
        DemandLines::CreateFromProvisional.call!(
          store: demand_store,
          actor: current_user,
          customer: customer,
          customer_name_snapshot: params[:customer_name_snapshot],
          customer_email_snapshot: params[:customer_email_snapshot],
          customer_phone_snapshot: params[:customer_phone_snapshot],
          preferred_contact_method: params[:preferred_contact_method],
          needed_by_date: params[:needed_by_date],
          notes: params[:notes],
          provisional_title: params[:provisional_title],
          provisional_identifier: params[:provisional_identifier],
          provisional_creator: params[:provisional_creator],
          quantity: params[:quantity].presence&.to_i || 1
        )
      else
        DemandLines::Create.call!(
          store: demand_store,
          actor: current_user,
          capture_intent: capture_intent,
          quantity: params[:quantity].presence&.to_i || 1,
          variant: variant,
          customer: customer,
          customer_name_snapshot: params[:customer_name_snapshot],
          customer_email_snapshot: params[:customer_email_snapshot],
          customer_phone_snapshot: params[:customer_phone_snapshot],
          preferred_contact_method: params[:preferred_contact_method],
          needed_by_date: params[:needed_by_date],
          expires_at: parse_expires_at,
          notes: params[:notes]
        )
      end

      redirect_to demand_demand_line_path(@demand_line), notice: "Demand line created."
    rescue DemandLines::Create::CreateError,
           DemandLines::CreateFromProvisional::CreateError => e
      @demand_line = DemandLine.new(demand_line_form_params)
      @demand_line.store = demand_store
      @demand_line.errors.add(:base, e.message)
      load_form_collections
      render :new, status: :unprocessable_entity
    end

    def cancel
      return unless authorize_demand!("demand.cancel")

      DemandLines::Cancel.call!(demand_line: @demand_line, actor: current_user, cancel_reason: params[:cancel_reason])
      redirect_to demand_demand_line_path(@demand_line), notice: "Demand line canceled."
    rescue DemandLines::Cancel::CancelError => e
      redirect_to demand_demand_line_path(@demand_line), alert: e.message
    end

    def expire
      return unless authorize_demand!("demand.expire")

      DemandLines::Expire.call!(demand_line: @demand_line, actor: current_user)
      redirect_to demand_demand_line_path(@demand_line), notice: "Demand line expired."
    rescue DemandLines::Expire::ExpireError => e
      redirect_to demand_demand_line_path(@demand_line), alert: e.message
    end

    def match_variant
      return unless authorize_demand!("demand.match_variant")

      variant = resolve_variant(id: params[:product_variant_id], required: true)
      DemandLines::MatchVariant.call!(demand_line: @demand_line, variant: variant, actor: current_user)
      redirect_to demand_demand_line_path(@demand_line), notice: "Variant matched."
    rescue DemandLines::MatchVariant::MatchError, ActiveRecord::RecordNotFound => e
      redirect_to demand_demand_line_path(@demand_line), alert: e.message
    end

    private

    def load_form_collections
      @capture_intents = DemandLine::CAPTURE_INTENTS
    end

    def demand_line_form_params
      params.permit(
        :capture_intent, :quantity, :customer_name_snapshot, :customer_email_snapshot,
        :customer_phone_snapshot, :preferred_contact_method, :needed_by_date, :notes,
        :provisional_title, :provisional_identifier, :provisional_creator, :product_variant_id
      )
    end

    def parse_expires_at
      return nil if params[:expires_at].blank?

      Time.zone.parse(params[:expires_at].to_s)
    end

    def apply_queue_filter!
      return if params[:queue].blank?

      @demand_lines = DemandLines::QueueScope.apply(@demand_lines, params[:queue], store: demand_store)
      @active_queue = params[:queue].to_s
    end

    def apply_allocation_filters!
      case params[:allocation_state].presence
      when "unallocated"
        @demand_lines = @demand_lines.where(status: "open")
      when "partially_allocated"
        @demand_lines = @demand_lines.where(status: "partially_allocated")
      when "allocated"
        @demand_lines = @demand_lines.where(status: "allocated")
      when "fulfilled"
        @demand_lines = @demand_lines.where(status: "fulfilled")
      end

      return if params[:allocation_kind].blank?

      @demand_lines = @demand_lines.joins(:demand_allocations)
                                   .merge(DemandAllocation.active_allocations.where(allocation_kind: params[:allocation_kind]))
                                   .distinct
    end

    def resolve_variant(id:, required:)
      return nil if id.blank?
      raise ActiveRecord::RecordNotFound, "Variant is required" if required && id.blank?

      ProductVariant.find(id)
    end

    def resolve_customer(id:, required:)
      return nil if id.blank?
      raise ActiveRecord::RecordNotFound, "Customer is required" if required && id.blank?

      Customer.find(id)
    end

    def load_sourcing_context!
      @sourcing_unresolved = Sourcing::UnresolvedQuantity.for_demand_line(@demand_line)
      @sourcing_eligibility = Sourcing::Eligibility.for_demand_line(@demand_line)
      @active_sourcing_run = SourcingRun.active_runs.find_by(demand_line_id: @demand_line.id)
      @latest_vendor_response = VendorResponse.joins(sourcing_attempt: :sourcing_run)
                                              .where(sourcing_runs: { demand_line_id: @demand_line.id })
                                              .order(responded_at: :desc)
                                              .first
    end
  end
end
