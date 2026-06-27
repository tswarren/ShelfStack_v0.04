# frozen_string_literal: true

module Pos
  class DraftCreator
    Error = Class.new(StandardError)
    Result = Data.define(:status, :transaction, :candidates)

    def self.call(store:, workstation:, cashier_user:, register_session:, user_session: nil)
      new(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        register_session: register_session,
        user_session: user_session
      ).call
    end

    def self.call!(...)
      result = call(...)
      case result.status
      when :conflict
        raise Error, "Multiple active drafts exist for this register session."
      when :missing_register_session
        raise Error, "Register session must be open."
      else
        result
      end
    end

    def initialize(store:, workstation:, cashier_user:, register_session:, user_session: nil)
      @store = store
      @workstation = workstation
      @cashier_user = cashier_user
      @register_session = register_session
      @user_session = user_session
    end

    def call
      return missing_register_session_result if register_session.blank? || !register_session.open?

      register_session.with_lock do
        resolution = ActiveDraftResolver.call(
          store: store,
          workstation: workstation,
          cashier_user: cashier_user,
          register_session: register_session
        )

        case resolution.status
        when :found
          Result.new(status: :resumed, transaction: resolution.draft, candidates: [])
        when :conflict
          Result.new(status: :conflict, transaction: nil, candidates: resolution.candidates)
        when :none
          Result.new(status: :created, transaction: create_stamped_draft!, candidates: [])
        end
      end
    end

    private

    attr_reader :store, :workstation, :cashier_user, :register_session, :user_session

    def create_stamped_draft!
      PosTransaction.create!(
        store: store,
        workstation: workstation,
        cashier_user: cashier_user,
        status: "draft",
        pos_register_session: register_session,
        business_date: register_session.business_date,
        user_session: user_session
      )
    end

    def missing_register_session_result
      Result.new(status: :missing_register_session, transaction: nil, candidates: [])
    end
  end
end
