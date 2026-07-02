# frozen_string_literal: true

module DemandLines
  class ExpireDue
    class ExpireDueError < StandardError; end

    Result = Data.define(:expired_demand_count, :expired_allocation_count)

    def self.call!(store: nil, actor: nil, now: Time.current)
      new(store:, actor:, now:).call!
    end

    def initialize(store: nil, actor: nil, now: Time.current)
      @store = store
      @actor = actor
      @now = now
    end

    def call!
      expired_demand_count = 0
      expired_allocation_count = 0
      system_actor = actor || User.find_by!(username: ShelfStack::SYSTEM_USERNAME)

      scope = DemandLine.where.not(status: DemandLine::TERMINAL_STATUSES)
                        .where("expires_at IS NOT NULL AND expires_at <= ?", now)
      scope = scope.where(store: store) if store.present?

      scope.find_each do |demand_line|
        DemandLine.transaction do
          locked = DemandLine.lock.find(demand_line.id)
          next if DemandLine::TERMINAL_STATUSES.include?(locked.status)
          next if locked.expires_at.blank? || locked.expires_at > now

          Sourcing::CancelActiveForDemand.call!(
            demand_line: locked,
            actor: system_actor,
            reason: "Demand expired due"
          )

          locked.demand_allocations.active_allocations.find_each do |allocation|
            DemandAllocations::Expire.call!(allocation: allocation, actor: nil, expired_at: now)
            expired_allocation_count += 1
          end

          locked.update!(
            status: "expired",
            expired_by_user: actor,
            expired_at: now
          )

          AuditEvents.record!(
            actor: system_actor,
            event_name: "demand_line.expired_due",
            auditable: locked,
            details: {
              "demand_number" => locked.demand_number,
              "system_expiry" => actor.nil?
            }
          )

          expired_demand_count += 1
        end
      end

      Result.new(expired_demand_count:, expired_allocation_count:)
    end

    private

    attr_reader :store, :actor, :now
  end
end
