# frozen_string_literal: true

module Buybacks
  class VoidSession
    class Error < StandardError; end

    def self.call!(session:, actor:, register_session: nil, void_reason:, pos_authorization: nil, notes: nil)
      new(session:, actor:, register_session:, void_reason:, pos_authorization:, notes:).call!
    end

    def initialize(session:, actor:, register_session: nil, void_reason:, pos_authorization: nil, notes: nil)
      @session = session
      @actor = actor
      @register_session = register_session
      @void_reason = void_reason
      @pos_authorization = pos_authorization
      @notes = notes
    end

    def call!
      raise Error, "Only completed buybacks can be voided." unless session.completed?
      raise Error, "Buyback is already voided." if session.voided?
      raise Error, "Void reason is required." if void_reason.blank?
      raise Error, "Supervisor authorization required to void cash payout." if cash_payout? && !authorization_valid?

      BuybackSession.transaction do
        buyback_void = BuybackVoid.create!(
          buyback_session: session,
          store: session.store,
          workstation: session.workstation,
          pos_register_session: register_session,
          voided_at: Time.current,
          voided_by_user: actor,
          void_reason: void_reason,
          pos_authorization: pos_authorization,
          notes: notes
        )

        PostVoidInventory.call(buyback_void:, posted_by_user: actor)
        reverse_cash_payout!(buyback_void) if cash_payout?
        reverse_trade_credit!(buyback_void) if trade_credit_payout?

        session.update!(
          status: "voided",
          voided_at: buyback_void.voided_at,
          voided_by_user: actor,
          void_reason: void_reason
        )

        AuditEvents.record!(actor: actor, event_name: "buyback.session.voided", auditable: session, source: buyback_void)
        AuditEvents.record!(actor: actor, event_name: "buyback.void.created", auditable: buyback_void, source: session)

        buyback_void
      end
    end

    private

    attr_reader :session, :actor, :register_session, :void_reason, :pos_authorization, :notes

    def cash_payout?
      session.payout_mode == "cash" && session.pos_cash_movement.present?
    end

    def trade_credit_payout?
      session.payout_mode == "trade_credit" && session.stored_value_ledger_entry.present?
    end

    def authorization_valid?
      return true unless cash_payout?

      Pos::AuthorizationRequest.valid_for?(
        authorization: pos_authorization,
        authorization_type: "void_buyback",
        pos_register_session: register_session
      )
    end

    def reverse_cash_payout!(buyback_void)
      raise Error, "Open register session is required to reverse cash payout." unless register_session&.open?

      original = session.pos_cash_movement
      movement = register_session.pos_cash_movements.create!(
        store: session.store,
        movement_type: "paid_in",
        amount_cents: original.amount_cents,
        reason_code: "buyback_void",
        recorded_at: Time.current,
        recorded_by_user: actor,
        source: buyback_void,
        reverses_cash_movement: original
      )
      buyback_void.update!(void_cash_movement: movement)
    end

    def reverse_trade_credit!(buyback_void)
      reason = StoredValueReasonCode.find_by!(reason_key: "buyback_trade_credit_void")
      entry = StoredValue::VoidEntry.call(
        entry: session.stored_value_ledger_entry,
        store: session.store,
        actor: actor,
        reason_code: reason,
        notes: "Void buyback #{session.buyback_number}"
      )
      buyback_void.update!(void_stored_value_ledger_entry: entry)
    end
  end
end
