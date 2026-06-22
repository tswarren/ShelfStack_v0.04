# frozen_string_literal: true

module Customers
  class ContactEventsController < BaseController
    before_action :set_customer
    before_action -> { authorize!("customer_requests.contact") }, only: :create

    def create
      CustomerRequests::RecordContact.call!(
        actor: current_user,
        customer: @customer,
        contact_method: params[:contact_method],
        direction: params[:direction] || "outbound",
        status: params[:status] || "attempted",
        summary: params[:summary]
      )
      redirect_to customers_customer_path(@customer), notice: "Contact recorded."
    rescue CustomerRequests::RecordContact::RecordError => e
      redirect_to customers_customer_path(@customer), alert: e.message
    end

    private

    def set_customer
      @customer = Customer.find(params[:customer_id])
    end
  end
end
