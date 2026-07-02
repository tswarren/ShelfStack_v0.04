# frozen_string_literal: true

module Pos
  class VoidTransaction
    Error = Class.new(StandardError)

    def self.call!(transaction:, voided_by_user:, register_session:, reason_code: nil, notes: nil, pos_authorization: nil)
      new(
        transaction:,
        voided_by_user:,
        register_session:,
        reason_code:,
        notes:,
        pos_authorization:
      ).call!
    end

    def initialize(transaction:, voided_by_user:, register_session:, reason_code: nil, notes: nil, pos_authorization: nil)
      @transaction = transaction
      @voided_by_user = voided_by_user
      @register_session = register_session
      @reason_code = reason_code
      @notes = notes
      @pos_authorization = pos_authorization
    end

    def call!
      raise Error, "Only completed transactions can be voided." unless transaction.completed?
      raise Error, "Transaction is already voided." if transaction.voided?
      raise Error, "Register session must be open." unless register_session&.open?
      raise Error, "Void reason is required." if reason_code.blank?
      raise Error, "Supervisor authorization required to void." unless authorization_valid?

      PosTransaction.transaction do
        pos_void = PosVoid.create!(
          pos_transaction: transaction,
          store: transaction.store,
          workstation: transaction.workstation,
          pos_register_session: register_session,
          voided_by_user: voided_by_user,
          pos_authorization: pos_authorization,
          voided_at: Time.current,
          business_date: register_session.business_date,
          reason_code: reason_code,
          notes: notes
        )

        transaction.update!(status: "voided", voided_at: pos_void.voided_at)

        PostVoidInventory.call(pos_void:, posted_by_user: voided_by_user)
        reverse_tenders!(pos_void)
        ReverseStoredValueLedger.call!(
          transaction:,
          actor: voided_by_user,
          pos_void:,
          store: transaction.store
        )

        AuditEvents.record!(
          actor: voided_by_user,
          event_name: "pos.transaction.voided",
          auditable: transaction,
          source: pos_void,
          details: { "pos_authorization_id" => pos_authorization.id }
        )
        AuditEvents.record!(
          actor: voided_by_user,
          event_name: "pos.void.completed",
          auditable: pos_void,
          source: transaction,
          details: {
            "transaction_number" => transaction.transaction_number,
            "pos_authorization_id" => pos_authorization.id
          }
        )

        pos_void
      end
    end

    private

    attr_reader :transaction, :voided_by_user, :register_session, :reason_code, :notes, :pos_authorization

    def authorization_valid?
      AuthorizationRequest.granted_for_transaction?(
        transaction: transaction,
        authorization_type: "void_transaction",
        pos_authorization_id: pos_authorization&.id
      )
    end

    def reverse_tenders!(pos_void)
      reversed_count = 0

      transaction.pos_tenders.settlement_rows.includes(:reversed_by_tender).find_each do |tender|
        next if tender.reversed_by_tender.present?

        PosTender.create!(
          pos_transaction: transaction,
          line_number: PosTender.next_line_number_for(transaction),
          tender_type: tender.tender_type,
          amount_cents: -tender.amount_cents,
          card_brand: tender.card_brand,
          card_last_four: tender.card_last_four,
          card_authorization_code: tender.card_authorization_code,
          check_number: tender.check_number,
          notes: tender.notes,
          stored_value_account_id: tender.stored_value_account_id,
          stored_value_identifier_id: tender.stored_value_identifier_id,
          reverses_tender: tender
        )
        reversed_count += 1
      end

      return unless reversed_count.positive?

      AuditEvents.record!(
        actor: voided_by_user,
        event_name: "pos.settlement.void_reversed",
        auditable: transaction,
        source: pos_void,
        details: { "reversal_count" => reversed_count }
      )
    end
  end
end
