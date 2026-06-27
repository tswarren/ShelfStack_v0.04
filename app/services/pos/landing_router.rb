# frozen_string_literal: true

module Pos
  class LandingRouter
    Result = Data.define(:status, :draft, :candidates, :legacy)

    def self.call(store:, workstation:, cashier_user:, register_session:)
      new(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session
      ).call
    end

    def initialize(store:, workstation:, cashier_user:, register_session:)
      @store = store
      @workstation = workstation
      @cashier_user = cashier_user
      @register_session = register_session
    end

    def call
      return closed_result if register_session.blank? || !register_session.open?

      resolution = ActiveDraftResolver.call(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session
      )

      case resolution.status
      when :found
        Result.new(status: :active_draft, draft: resolution.draft, candidates: [], legacy: false)
      when :legacy_found
        Result.new(status: :legacy_found, draft: resolution.draft, candidates: resolution.candidates, legacy: true)
      when :conflict
        Result.new(status: :conflict, draft: nil, candidates: resolution.candidates, legacy: resolution.legacy)
      when :none
        Result.new(status: :idle, draft: nil, candidates: [], legacy: false)
      else
        raise DraftCreator::Error, "Unexpected active draft resolution: #{resolution.status.inspect}"
      end
    end

    private

    attr_reader :store, :workstation, :cashier_user, :register_session

    def closed_result
      Result.new(status: :closed, draft: nil, candidates: [], legacy: false)
    end
  end
end
