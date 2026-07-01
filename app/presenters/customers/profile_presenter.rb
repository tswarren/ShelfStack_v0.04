# frozen_string_literal: true

module Customers
  class ProfilePresenter
    def self.build(customer:, store:, user:)
      new(customer:, store:, user:).build
    end

    def initialize(customer:, store:, user:)
      @customer = customer
      @store = store
      @user = user
    end

    def build
      self
    end

    attr_reader :customer, :store, :user

    def open_request_count
      @open_request_count ||= customer.customer_requests
                                      .where(store: store)
                                      .merge(CustomerRequest.open_requests)
                                      .count
    end

    def active_hold_count
      @active_hold_count ||= InventoryReservation.active_on_hand
                                                 .where(store: store, customer: customer, reservation_type: "on_hand_hold")
                                                 .count
    end

    def ready_for_pickup_line_count
      @ready_for_pickup_line_count ||= CustomerRequestLine.open_lines
                                                          .joins(:customer_request)
                                                          .where(customer_requests: { store_id: store.id, customer_id: customer.id })
                                                          .where(status: "ready_for_pickup")
                                                          .count
    end

    def can_create_demand?
      Authorization.allowed?(user: user, permission_key: "demand.create", store: store)
    end

    def can_create_request?
      return false if can_create_demand?

      Authorization.allowed?(user: user, permission_key: "customer_requests.create", store: store)
    end

    def can_record_contact?
      Authorization.allowed?(user: user, permission_key: "customer_requests.contact", store: store)
    end

    def can_view_requests?
      Authorization.allowed?(user: user, permission_key: "customer_requests.access", store: store)
    end

    def ready_pickups_path
      Rails.application.routes.url_helpers.customers_customer_requests_path(
        queue: "ready_for_pickup",
        q: customer.display_name
      )
    end

    def active_holds_path
      Rails.application.routes.url_helpers.customers_customer_requests_path(
        queue: "expiring_holds",
        q: customer.display_name
      )
    end

    def new_request_path
      Rails.application.routes.url_helpers.new_customers_customer_request_path(customer_id: customer.id)
    end

    def new_demand_path
      Rails.application.routes.url_helpers.new_demand_demand_line_path(customer_id: customer.id)
    end
  end
end
