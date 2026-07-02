# frozen_string_literal: true

module Customers
  class ContactEventsController < BaseController
    before_action :set_customer
    before_action -> { authorize!("customer_requests.contact") }, only: :create

    def create
      CustomerContactEvent.create!(
        customer: @customer,
        recorded_by_user: current_user,
        contact_method: params[:contact_method],
        direction: params[:direction] || "outbound",
        status: params[:status] || "attempted",
        summary: params[:summary],
        occurred_at: Time.current
      )
      redirect_to customers_customer_path(@customer), notice: "Contact recorded."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to customers_customer_path(@customer), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_customer
      @customer = Customer.find(params[:customer_id])
    end
  end
end
