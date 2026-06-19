# frozen_string_literal: true

module Pos
  class VoidTransaction
    Error = Class.new(StandardError)

    def self.call!(transaction:, voided_by_user:, register_session:, reason_code: nil, notes: nil)
      new(transaction:, voided_by_user:, register_session:, reason_code:, notes:).call!
    end

    def initialize(transaction:, voided_by_user:, register_session:, reason_code: nil, notes: nil)
      @transaction = transaction
      @voided_by_user = voided_by_user
      @register_session = register_session
      @reason_code = reason_code
      @notes = notes
    end

    def call!
      raise Error, "Only completed transactions can be voided." unless transaction.completed?
      raise Error, "Transaction is already voided." if transaction.voided?
      raise Error, "Register session must be open." unless register_session&.open?

      PosTransaction.transaction do
        pos_void = PosVoid.create!(
          pos_transaction: transaction,
          store: transaction.store,
          workstation: transaction.workstation,
          pos_register_session: register_session,
          voided_by_user: voided_by_user,
          voided_at: Time.current,
          business_date: register_session.business_date,
          reason_code: reason_code,
          notes: notes
        )

        transaction.update!(status: "voided", voided_at: pos_void.voided_at)

        PostVoidInventory.call(pos_void:, posted_by_user: voided_by_user)
        reverse_tenders!(pos_void)

        AuditEvents.record!(
          actor: voided_by_user,
          event_name: "pos.transaction.voided",
          auditable: transaction,
          source: pos_void
        )
        AuditEvents.record!(
          actor: voided_by_user,
          event_name: "pos.void.completed",
          auditable: pos_void,
          source: transaction,
          details: { "transaction_number" => transaction.transaction_number }
        )

        pos_void
      end
    end

    private

    attr_reader :transaction, :voided_by_user, :register_session, :reason_code, :notes

    def reverse_tenders!(pos_void)
      transaction.pos_tenders.where(reverses_tender_id: nil).find_each do |tender|
        PosTender.create!(
          pos_transaction: transaction,
          tender_type: tender.tender_type,
          amount_cents: -tender.amount_cents,
          reference_number: tender.reference_number,
          reverses_tender: tender
        )
      end
    end
  end
end
