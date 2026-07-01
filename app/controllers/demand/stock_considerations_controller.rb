# frozen_string_literal: true

module Demand
  class StockConsiderationsController < BaseController
    before_action -> { authorize_demand!("stock_considerations.access") }, only: %i[index show]
    before_action -> { authorize_demand!("stock_considerations.create") }, only: %i[new create]
    before_action -> { authorize_demand!("stock_considerations.convert") }, only: :convert
    before_action -> { authorize_demand!("stock_considerations.dismiss") }, only: :dismiss
    before_action :set_stock_consideration, only: %i[show convert dismiss]

    def index
      @stock_considerations = StockConsideration.includes(:product_variant, :created_by_user)
                                                .where(store: demand_store)
                                                .order(created_at: :desc)
      @stock_considerations = @stock_considerations.open_queue if params[:queue] == "open"
    end

    def show; end

    def new
      @stock_consideration = StockConsideration.new(store: demand_store)
    end

    def create
      variant = params[:product_variant_id].present? ? ProductVariant.find(params[:product_variant_id]) : nil
      @stock_consideration = StockConsiderations::Create.call!(
        store: demand_store,
        actor: current_user,
        variant: variant,
        provisional_title: params[:provisional_title],
        provisional_identifier: params[:provisional_identifier],
        provisional_creator: params[:provisional_creator],
        reason: params[:reason],
        priority: params[:priority],
        quantity_suggested: params[:quantity_suggested].presence&.to_i,
        notes: params[:notes]
      )
      redirect_to demand_stock_consideration_path(@stock_consideration), notice: "Stock consideration created."
    rescue StockConsiderations::Create::CreateError => e
      @stock_consideration = StockConsideration.new(stock_consideration_params)
      @stock_consideration.store = demand_store
      @stock_consideration.errors.add(:base, e.message)
      render :new, status: :unprocessable_entity
    end

    def convert
      return unless authorize_demand!("stock_considerations.convert")

      demand_line = StockConsiderations::ConvertToDemand.call!(
        consideration: @stock_consideration,
        actor: current_user,
        capture_intent: params[:capture_intent].presence || "buyer_replenishment",
        quantity: params[:quantity].presence&.to_i
      )
      redirect_to demand_demand_line_path(demand_line), notice: "Converted to demand."
    rescue StockConsiderations::ConvertToDemand::ConvertError => e
      redirect_to demand_stock_consideration_path(@stock_consideration), alert: e.message
    end

    def dismiss
      return unless authorize_demand!("stock_considerations.dismiss")

      StockConsiderations::Dismiss.call!(
        consideration: @stock_consideration,
        actor: current_user,
        dismiss_reason: params[:dismiss_reason],
        status: params[:status].presence || "dismissed"
      )
      redirect_to demand_stock_consideration_path(@stock_consideration), notice: "Stock consideration dismissed."
    rescue StockConsiderations::Dismiss::DismissError => e
      redirect_to demand_stock_consideration_path(@stock_consideration), alert: e.message
    end

    private

    def stock_consideration_params
      params.permit(
        :provisional_title, :provisional_identifier, :provisional_creator,
        :reason, :priority, :quantity_suggested, :notes, :product_variant_id
      )
    end
  end
end
