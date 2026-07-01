# frozen_string_literal: true

module Demand
  class AllocationsController < BaseController
    before_action -> { authorize_demand!("demand.allocations.release") }, only: :release
    before_action -> { authorize_demand!("demand.allocations.cancel") }, only: :cancel
    before_action -> { authorize_demand!("demand.allocations.expire") }, only: :expire
    before_action -> { authorize_demand!("demand.allocations.fulfill") }, only: :fulfill
    before_action :set_demand_line, only: :create
    before_action :set_allocation, only: %i[release cancel expire fulfill]

    def create
      return unless authorize_demand!("demand.allocations.create")

      allocation = if params[:allocation_kind] == "inbound_purchase_order"
        po_line = PurchaseOrderLine.find(params[:purchase_order_line_id])
        DemandAllocations::AllocateInboundPurchaseOrder.call!(
          demand_line: @demand_line,
          purchase_order_line: po_line,
          actor: current_user,
          quantity: params[:quantity].presence&.to_i || 1,
          notes: params[:notes]
        )
      else
        override = ActiveModel::Type::Boolean.new.cast(params[:override_availability]) == true
        if override && !Authorization.allowed?(user: current_user, permission_key: "demand.allocations.override_availability", store: demand_store)
          return redirect_to demand_demand_line_path(@demand_line), alert: "Override authorization required."
        end

        DemandAllocations::AllocateOnHand.call!(
          demand_line: @demand_line,
          actor: current_user,
          quantity: params[:quantity].presence&.to_i || 1,
          override_availability: override,
          override_reason: params[:override_reason],
          override_authorized_by_user: override ? current_user : nil,
          notes: params[:notes]
        )
      end

      redirect_to demand_demand_line_path(@demand_line), notice: "Allocation created (#{allocation.allocation_kind})."
    rescue DemandAllocations::AllocateOnHand::AllocateError,
           DemandAllocations::AllocateInboundPurchaseOrder::AllocateError,
           ActiveRecord::RecordNotFound => e
      redirect_to demand_demand_line_path(@demand_line), alert: e.message
    end

    def release
      DemandAllocations::Release.call!(allocation: @allocation, actor: current_user, release_reason: params[:release_reason])
      redirect_to demand_demand_line_path(@allocation.demand_line), notice: "Allocation released."
    rescue DemandAllocations::Release::ReleaseError => e
      redirect_to demand_demand_line_path(@allocation.demand_line), alert: e.message
    end

    def cancel
      DemandAllocations::Cancel.call!(allocation: @allocation, actor: current_user, cancel_reason: params[:cancel_reason])
      redirect_to demand_demand_line_path(@allocation.demand_line), notice: "Allocation canceled."
    rescue DemandAllocations::Cancel::CancelError => e
      redirect_to demand_demand_line_path(@allocation.demand_line), alert: e.message
    end

    def expire
      DemandAllocations::Expire.call!(allocation: @allocation, actor: current_user)
      redirect_to demand_demand_line_path(@allocation.demand_line), notice: "Allocation expired."
    rescue DemandAllocations::Expire::ExpireError => e
      redirect_to demand_demand_line_path(@allocation.demand_line), alert: e.message
    end

    def fulfill
      DemandAllocations::Fulfill.call!(allocation: @allocation, actor: current_user)
      redirect_to demand_demand_line_path(@allocation.demand_line), notice: "Allocation fulfilled."
    rescue DemandAllocations::Fulfill::FulfillError => e
      redirect_to demand_demand_line_path(@allocation.demand_line), alert: e.message
    end

    private

    def set_demand_line
      @demand_line = DemandLine.where(store: demand_store).find(params[:demand_line_id])
    end

    def set_allocation
      @allocation = DemandAllocation.joins(:demand_line)
                                    .where(demand_lines: { store_id: demand_store.id })
                                    .find(params[:id])
    end
  end
end
