# frozen_string_literal: true

module Sourcing
  module CascadeEligibleQuantity
    module_function

    def for_attempt(sourcing_attempt)
      response = sourcing_attempt.vendor_responses.where(final_response: true).order(responded_at: :desc).first
      return 0 if response.blank?

      eligible = response.quantity_unavailable + response.quantity_canceled + response.quantity_failed

      backorder_gap = response.quantity_backordered -
                      vendor_backorder_allocated(sourcing_attempt, response)
      eligible += backorder_gap if backorder_gap.positive?

      [ eligible, 0 ].max
    end

    def vendor_backorder_allocated(sourcing_attempt, response)
      DemandAllocation.active_allocations.vendor_backorder_kind
                      .where(sourcing_attempt: sourcing_attempt)
                      .or(
                        DemandAllocation.active_allocations.vendor_backorder_kind
                                        .where(vendor_response: response)
                      )
                      .sum(:quantity_allocated)
    end
  end
end
