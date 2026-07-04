# frozen_string_literal: true

module Sourcing
  class NextActionPresenter
    Action = Data.define(
      :next_action_key,
      :next_action_label,
      :next_action_description,
      :warning_message,
      :eligible_actions
    )

    def self.call(demand_line:, sourcing_run: nil, sourcing_attempt: nil, vendor: nil, unresolved_quantity: nil)
      new(
        demand_line:,
        sourcing_run:,
        sourcing_attempt:,
        vendor:,
        unresolved_quantity:
      ).call
    end

    def initialize(demand_line:, sourcing_run: nil, sourcing_attempt: nil, vendor: nil, unresolved_quantity: nil)
      @demand_line = demand_line
      @sourcing_run = sourcing_run
      @sourcing_attempt = sourcing_attempt
      @vendor = vendor || sourcing_attempt&.vendor
      @unresolved_quantity = unresolved_quantity
    end

    def call
      capability = resolved_capability
      Action.new(
        next_action_key: next_action_key(capability),
        next_action_label: next_action_label(capability),
        next_action_description: next_action_description(capability),
        warning_message: warning_message,
        eligible_actions: eligible_actions(capability)
      )
    end

    private

    attr_reader :demand_line, :sourcing_run, :sourcing_attempt, :vendor, :unresolved_quantity

    def resolved_capability
      return Vendors::CapabilityResolver.call(vendor:) if vendor.present?

      nil
    end

    def next_action_key(capability)
      return "review_sourcing_run" if sourcing_run&.active? && sourcing_attempt.blank?
      return "await_vendor_response" if sourcing_attempt&.in_flight?
      return "record_manual_response" if capability&.availability_workflow == "manual_review"
      return "order_to_confirm" if capability&.availability_workflow == "order_to_confirm"
      return "check_availability" if capability&.availability_workflow == "check_before_order"

      "choose_vendor"
    end

    def next_action_label(capability)
      case next_action_key(capability)
      when "check_availability" then "Check availability"
      when "order_to_confirm" then "Order to confirm"
      when "record_manual_response" then "Record manual response"
      when "await_vendor_response" then "Await vendor response"
      when "review_sourcing_run" then "Review sourcing run"
      else "Choose vendor"
      end
    end

    def next_action_description(capability)
      case next_action_key(capability)
      when "check_availability"
        "Check vendor availability before committing to an order."
      when "order_to_confirm"
        "Submit or add to a purchase order; availability is confirmed after ordering."
      when "record_manual_response"
        "Record the vendor outcome manually after contact."
      when "await_vendor_response"
        "Waiting for vendor response on the current attempt."
      when "review_sourcing_run"
        "Review the active sourcing run and next vendor step."
      else
        "Select a vendor and start sourcing."
      end
    end

    def warning_message
      qty = unresolved_quantity || Sourcing::UnresolvedQuantity.for_demand_line(demand_line)
      return nil if qty.to_i <= 0

      nil
    end

    def eligible_actions(capability)
      key = next_action_key(capability)
      case key
      when "check_availability" then %w[check_availability submit_attempt cascade]
      when "order_to_confirm" then %w[add_to_po submit_attempt record_response]
      when "record_manual_response" then %w[record_response cascade]
      when "await_vendor_response" then %w[record_response cancel_attempt]
      when "review_sourcing_run" then %w[create_attempt cascade close_run]
      else %w[start_run choose_vendor]
      end
    end
  end
end
