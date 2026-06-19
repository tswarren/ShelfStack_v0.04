# frozen_string_literal: true

module Pos
  class AuthorizationRequest
    Error = Class.new(StandardError)

    TRANSACTION_DISCOUNT_LIMIT_CENTS = 5_000

    def self.grant!(authorization_type:, requested_by:, manager_username:, manager_pin:, store:, pos_transaction: nil, pos_register_session: nil, details: {})
      new(
        authorization_type:,
        requested_by:,
        manager_username:,
        manager_pin:,
        store:,
        pos_transaction:,
        pos_register_session:,
        details:
      ).grant!
    end

    def initialize(authorization_type:, requested_by:, manager_username:, manager_pin:, store:, pos_transaction: nil, pos_register_session: nil, details: {})
      @authorization_type = authorization_type
      @requested_by = requested_by
      @manager_username = manager_username.to_s.strip
      @manager_pin = manager_pin
      @store = store
      @pos_transaction = pos_transaction
      @pos_register_session = pos_register_session
      @details = details
    end

    def grant!
      manager = User.active_records.find_by(username: manager_username)
      raise Error, "Manager not found." if manager.blank?
      raise Error, "Invalid manager PIN." unless manager.authenticate_pin(manager_pin)
      raise Error, "Manager is not authorized to grant approvals." unless Authorization.allowed?(
        user: manager,
        permission_key: "pos.authorizations.grant",
        store: store
      )

      authorization = PosAuthorization.create!(
        store: store,
        pos_transaction: pos_transaction,
        pos_register_session: pos_register_session,
        authorization_type: authorization_type,
        requested_by_user: requested_by,
        granted_by_user: manager,
        granted_at: Time.current,
        details: details
      )

      AuditEvents.record!(
        actor: manager,
        event_name: "pos.authorization.granted",
        auditable: authorization,
        source: pos_transaction,
        details: { "authorization_type" => authorization_type }
      )

      authorization
    end

    def self.valid_for?(authorization:, authorization_type:, pos_transaction: nil, pos_register_session: nil)
      return false if authorization.blank?
      return false unless authorization.granted?
      return false unless authorization.authorization_type == authorization_type
      return false if pos_transaction.present? && authorization.pos_transaction_id != pos_transaction.id
      return false if pos_register_session.present? && authorization.pos_register_session_id != pos_register_session.id

      true
    end

    private

    attr_reader :authorization_type, :requested_by, :manager_username, :manager_pin, :store,
                :pos_transaction, :pos_register_session, :details
  end
end
