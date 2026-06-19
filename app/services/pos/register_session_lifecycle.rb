# frozen_string_literal: true

module Pos
  class RegisterSessionLifecycle
    Error = Class.new(StandardError)

    def self.open!(store:, workstation:, opened_by_user:, business_date:, opening_cash_cents: 0, notes: nil)
      if PosRegisterSession.open_for_workstation(workstation)
        raise Error, "Workstation already has an open register session."
      end

      session = PosRegisterSession.create!(
        store: store,
        workstation: workstation,
        opened_by_user: opened_by_user,
        status: "open",
        business_date: business_date,
        opening_cash_cents: opening_cash_cents,
        opened_at: Time.current,
        notes: notes
      )

      AuditEvents.record!(
        actor: opened_by_user,
        event_name: "pos.register_session.opened",
        auditable: session,
        details: { "business_date" => business_date.to_s }
      )

      session
    end

    def self.close!(session:, closed_by_user:, expected_closing_cash_cents:, counted_closing_cash_cents:, force: false)
      raise Error, "Register session is not open." unless session.open?

      suspended_count = PosTransaction.suspended.where(workstation: session.workstation).count
      if force && suspended_count.positive?
        AuditEvents.record!(
          actor: closed_by_user,
          event_name: "pos.register_session.force_closed",
          auditable: session,
          details: { "suspended_transaction_count" => suspended_count }
        )
      end

      session.update!(
        status: force ? "force_closed" : "closed",
        closed_by_user: closed_by_user,
        expected_closing_cash_cents: expected_closing_cash_cents,
        counted_closing_cash_cents: counted_closing_cash_cents,
        closed_at: Time.current,
        force_closed: force
      )

      AuditEvents.record!(
        actor: closed_by_user,
        event_name: force ? "pos.register_session.force_closed" : "pos.register_session.closed",
        auditable: session
      )

      session
    end
  end
end
