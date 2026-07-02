# frozen_string_literal: true

module Sourcing
  module CancelActiveForDemand
    module_function

    def call!(demand_line:, actor:, reason:)
      SourcingRun.active_runs.where(demand_line_id: demand_line.id).find_each do |run|
        CancelRun.call!(sourcing_run: run, actor: actor, cancel_reason: reason)
      end
    end
  end
end
