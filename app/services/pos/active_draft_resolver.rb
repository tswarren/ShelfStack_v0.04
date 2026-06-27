# frozen_string_literal: true

module Pos
  class ActiveDraftResolver
    Result = Data.define(:status, :draft, :candidates, :legacy)

    def self.call(store:, workstation:, cashier_user:, register_session: nil)
      new(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session
      ).call
    end

    def initialize(store:, workstation:, cashier_user:, register_session: nil)
      @store = store
      @workstation = workstation
      @cashier_user = cashier_user
      @register_session = register_session
    end

    def call
      if register_session.present?
        session_scoped = scoped_drafts.where(pos_register_session: register_session).order(updated_at: :desc).to_a
        return single_result(session_scoped.first) if session_scoped.one?
        return conflict_result(session_scoped, legacy: false) if session_scoped.many?

        return legacy_fallback
      end

      legacy_fallback
    end

    private

    attr_reader :store, :workstation, :cashier_user, :register_session

    def scoped_drafts
      PosTransaction.drafts.where(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user
      )
    end

    def legacy_drafts
      scoped_drafts.where(pos_register_session_id: nil).order(updated_at: :desc).to_a
    end

    def legacy_fallback
      candidates = legacy_drafts
      return none_result if candidates.empty?
      return single_result(candidates.first, legacy: true) if candidates.one?

      conflict_result(candidates, legacy: true)
    end

    def none_result
      Result.new(status: :none, draft: nil, candidates: [], legacy: false)
    end

    def single_result(draft, legacy: false)
      Result.new(status: :found, draft: draft, candidates: [], legacy: legacy)
    end

    def conflict_result(candidates, legacy:)
      Result.new(status: :conflict, draft: nil, candidates: candidates, legacy: legacy)
    end
  end
end
