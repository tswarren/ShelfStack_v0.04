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
      @open_request_count ||= DemandLine.where(store: store, customer: customer)
                                        .where.not(status: DemandLine::TERMINAL_STATUSES)
                                        .count
    end

    def active_hold_count
      @active_hold_count ||= DemandAllocation.active_allocations
                                             .on_hand_kind
                                             .joins(:demand_line)
                                             .where(store: store, demand_lines: { customer_id: customer.id, capture_intent: "hold" })
                                             .count
    end

    def ready_for_pickup_line_count
      @ready_for_pickup_line_count ||= DemandLines::QueueScope.ready_for_pickup_relation(
        DemandLine.where(store: store, customer: customer)
      ).count
    end

    def can_create_demand?
      Authorization.allowed?(user: user, permission_key: "demand.create", store: store)
    end

    def can_create_request?
      false
    end

    def can_record_contact?
      Authorization.allowed?(user: user, permission_key: "customers.update", store: store)
    end

    def can_view_requests?
      Authorization.allowed?(user: user, permission_key: "demand.access", store: store)
    end

    def ready_pickups_path
      Rails.application.routes.url_helpers.demand_demand_lines_path(
        queue: "ready_for_pickup",
        q: customer.display_name
      )
    end

    def active_holds_path
      Rails.application.routes.url_helpers.demand_demand_lines_path(
        queue: "expiring_holds",
        q: customer.display_name
      )
    end

    def new_request_path
      new_demand_path
    end

    def new_demand_path
      Rails.application.routes.url_helpers.new_demand_demand_line_path(customer_id: customer.id)
    end
  end
end
