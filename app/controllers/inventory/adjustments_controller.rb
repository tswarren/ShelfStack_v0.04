# frozen_string_literal: true

module Inventory
  class AdjustmentsController < BaseController
    before_action :set_adjustment, only: %i[show edit update post cancel]
    before_action -> { authorize!("inventory.adjustments.view") }, only: %i[index show]
    before_action -> { authorize!("inventory.adjustments.create") }, only: %i[new create edit update]
    before_action -> { authorize!("inventory.adjustments.post") }, only: :post
    before_action -> { authorize!("inventory.adjustments.cancel") }, only: :cancel

    def index
      @adjustments = InventoryAdjustment
        .includes(:posted_by_user)
        .where(store: inventory_store)
        .order(created_at: :desc)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@adjustment).limit(50)
    end

    def new
      @adjustment = InventoryAdjustment.new(
        store: inventory_store,
        adjustment_type: params[:adjustment_type].presence || "manual_adjustment",
        status: "draft"
      )
      @adjustment.inventory_adjustment_lines.build
      load_form_collections
    end

    def create
      @adjustment = InventoryAdjustment.new(adjustment_params)
      @adjustment.store = inventory_store
      @adjustment.status = "draft"

      if @adjustment.save
        record_audit!("inventory_adjustment.created", @adjustment)
        redirect_to inventory_adjustment_path(@adjustment), notice: "Draft adjustment created."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      redirect_to inventory_adjustment_path(@adjustment), alert: "Posted adjustments cannot be edited." unless @adjustment.draft?
      load_form_collections
    end

    def update
      unless @adjustment.draft?
        redirect_to inventory_adjustment_path(@adjustment), alert: "Posted adjustments cannot be edited."
        return
      end

      if @adjustment.update(adjustment_params)
        record_audit!("inventory_adjustment.updated", @adjustment)
        redirect_to inventory_adjustment_path(@adjustment), notice: "Draft adjustment updated."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def post
      Inventory::PostAdjustment.call(adjustment: @adjustment, posted_by_user: current_user)
      redirect_to inventory_adjustment_path(@adjustment), notice: "Adjustment posted."
    rescue Inventory::PostAdjustment::PostingError, Inventory::Eligibility::IneligibleVariantError => e
      redirect_to inventory_adjustment_path(@adjustment), alert: e.message
    end

    def cancel
      unless @adjustment.draft?
        redirect_to inventory_adjustment_path(@adjustment), alert: "Only draft adjustments can be cancelled."
        return
      end

      @adjustment.cancel!
      record_audit!("inventory_adjustment.cancelled", @adjustment)
      redirect_to inventory_adjustments_path, notice: "Adjustment cancelled."
    end

    private

    def set_adjustment
      @adjustment = InventoryAdjustment.where(store: inventory_store).find(params[:id])
    end

    def load_form_collections
      @variants = ProductVariant.active_records.order(:sku).limit(500)
      @reason_codes = InventoryReasonCode.active_records.order(:sort_order, :name)
      @locations = InventoryLocation.active_records.where(store: inventory_store).order(:sort_order, :name)
    end

    def adjustment_params
      params.require(:inventory_adjustment).permit(
        :adjustment_type,
        :notes,
        inventory_adjustment_lines_attributes: %i[
          id line_number product_variant_id quantity_delta unit_cost_cents
          inventory_location_id inventory_reason_code_id _destroy
        ]
      )
    end
  end
end
