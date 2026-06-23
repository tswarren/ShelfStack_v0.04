# frozen_string_literal: true

module Pos
  class PostStoredValueLedger
    Error = Class.new(StandardError)

    def self.call!(transaction:, actor:, store: nil)
      new(transaction:, actor:, store:).call!
    end

    def initialize(transaction:, actor:, store: nil)
      @transaction = transaction
      @actor = actor
      @store = store || transaction.store
    end

    def call!
      tenders = stored_value_tenders
      return Result.new(entries: [], generated_identifiers: []) if tenders.empty?

      @generated_identifiers = []
      validate_permissions!(tenders)
      validate_redemption_limits!(tenders)
      resolve_missing_accounts!(tenders)
      ensure_issue_identifiers!(tenders)

      entries = []
      lock_accounts!(tenders) do
        tenders.each do |tender|
          entries << post_for_tender!(tender)
        end
      end

      Result.new(entries:, generated_identifiers: @generated_identifiers)
    end

    Result = Data.define(:entries, :generated_identifiers)

    private

    attr_reader :transaction, :actor, :store

    def stored_value_tenders
      transaction.pos_tenders.settlement_rows.select(&:stored_value_tender?)
    end

    def validate_permissions!(tenders)
      tenders.each do |tender|
        if tender.issue_tender?(transaction)
          unless TenderTypePolicy.refund_store_credit_permitted?(actor:, store: store)
            raise Error, "You are not authorized to issue store credit from POS."
          end
        elsif tender.redeem_tender?(transaction)
          permission = tender.tender_type == "gift_card" ? "pos.tenders.gift_card" : "pos.tenders.store_credit"
          unless Authorization.allowed?(user: actor, permission_key: permission, store: store)
            raise Error, "You are not authorized to redeem #{tender.tender_type.humanize.downcase} at POS."
          end
        else
          raise Error, "Invalid stored value tender amount for transaction total."
        end
      end
    end

    def validate_redemption_limits!(tenders)
      redeem_total = tenders.select { |t| t.redeem_tender?(transaction) }.sum(&:amount_cents)
      return if redeem_total.zero?

      other_total = transaction.pos_tenders.settlement_rows.reject(&:stored_value_tender?).sum(&:amount_cents)
      if redeem_total + other_total > transaction.total_cents
        raise Error, "Stored value redemption exceeds transaction amount due."
      end

      tenders.select { |t| t.redeem_tender?(transaction) }.each do |tender|
        next if tender.stored_value_account.blank?

        capped = StoredValueTenderSupport.capped_redeem_amount_cents(
          transaction:,
          tender_type: tender.tender_type,
          amount_cents: tender.amount_cents,
          account: tender.stored_value_account
        )
        if tender.amount_cents > capped
          raise Error, "Redemption exceeds available account balance."
        end
      end
    end

    def resolve_missing_accounts!(tenders)
      tenders.each do |tender|
        next if tender.stored_value_account_id.present?

        result = StoredValueAccountResolver.resolve!(
          transaction:,
          tender_type: tender.tender_type,
          actor:,
          generate_identifier: tender.generate_stored_value_identifier?
        )
        tender.update!(
          stored_value_account: result.account,
          stored_value_identifier: result.identifier
        )
      end

      tenders.each do |tender|
        raise Error, "Stored value account is required." if tender.stored_value_account.blank?
        raise Error, "Stored value account is not active." unless tender.stored_value_account.postable?
      end
    end

    def ensure_issue_identifiers!(tenders)
      tenders.select { |tender| tender.issue_tender?(transaction) }.each do |tender|
        next unless tender.generate_stored_value_identifier?
        next if tender.stored_value_identifier_id.present?

        generated = GenerateStoredValueIdentifier.call!(tender:, actor:, store: store)
        @generated_identifiers << generated
      end
    end

    def lock_accounts!(tenders)
      account_ids = tenders.filter_map(&:stored_value_account_id).uniq.sort
      accounts = StoredValueAccount.where(id: account_ids).order(:id).lock.to_a
      raise Error, "Stored value account not found." if accounts.size != account_ids.size

      yield
    end

    def post_for_tender!(tender)
      if tender.issue_tender?(transaction)
        post_issue!(tender)
      else
        post_redeem!(tender)
      end
    end

    def post_issue!(tender)
      amount_cents = tender.amount_cents.abs
      reason_code = StoredValueReasonCode.find_by!(reason_key: "pos_return_credit")

      entry = StoredValue::Post.call(
        account: tender.stored_value_account,
        store: store,
        actor: actor,
        entry_type: "issue",
        amount_delta_cents: amount_cents,
        reason_code: reason_code,
        source: tender,
        notes: tender.notes,
        audit_event_name: "stored_value.ledger.issued"
      )

      record_pos_audit!("pos.stored_value.issued", tender, entry, amount_cents)
      entry
    end

    def post_redeem!(tender)
      entry = StoredValue::RedeemCredit.call(
        account: tender.stored_value_account,
        store: store,
        actor: actor,
        amount_cents: tender.amount_cents,
        source: tender,
        notes: tender.notes
      )

      record_pos_audit!("pos.stored_value.redeemed", tender, entry, tender.amount_cents)
      entry
    end

    def record_pos_audit!(event_name, tender, entry, amount_cents)
      AuditEvents.record!(
        actor: actor,
        event_name: event_name,
        auditable: entry,
        source: transaction,
        details: {
          "store_id" => store.id,
          "pos_transaction_id" => transaction.id,
          "pos_tender_id" => tender.id,
          "stored_value_account_id" => tender.stored_value_account_id,
          "amount_cents" => amount_cents,
          "balance_after_cents" => entry.balance_after_cents
        }
      )
    end
  end
end
