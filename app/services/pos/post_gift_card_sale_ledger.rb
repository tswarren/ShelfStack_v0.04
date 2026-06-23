# frozen_string_literal: true

module Pos
  class PostGiftCardSaleLedger
    Error = Class.new(StandardError)

    Result = Data.define(:entries, :generated_identifiers)

    def self.call!(transaction:, actor:, store: nil)
      new(transaction:, actor:, store:).call!
    end

    def initialize(transaction:, actor:, store: nil)
      @transaction = transaction
      @actor = actor
      @store = store || transaction.store
    end

    def call!
      lines = gift_card_sale_lines
      return Result.new(entries: [], generated_identifiers: []) if lines.empty?

      authorize!
      @generated_identifiers = []
      entries = []

      lock_accounts!(lines) do
        lines.each do |line|
          entries << post_for_line!(line)
        end
      end

      Result.new(entries:, generated_identifiers: @generated_identifiers)
    end

    private

    attr_reader :transaction, :actor, :store

    def gift_card_sale_lines
      transaction.pos_transaction_lines.select(&:gift_card_sale_line?)
    end

    def authorize!
      return if GiftCardSalePolicy.issue_permitted?(actor:, store: store)

      raise Error, "You are not authorized to sell gift cards at POS."
    end

    def lock_accounts!(lines)
      account_ids = lines.filter_map(&:stored_value_account_id).uniq.sort
      if account_ids.any?
        accounts = StoredValueAccount.where(id: account_ids).order(:id).lock.to_a
        raise Error, "Stored value account not found." if accounts.size != account_ids.size
      end

      yield
    end

    def post_for_line!(line)
      resolve_line_account!(line)
      ensure_identifier!(line)

      amount_cents = GiftCardSaleSupport.activation_amount_cents(line)
      raise Error, "Gift card sale amount must be positive." if amount_cents <= 0

      reason_code = StoredValueReasonCode.find_by!(reason_key: "pos_gift_card_sale")
      entry = StoredValue::Post.call(
        account: line.stored_value_account,
        store: store,
        actor: actor,
        entry_type: "issue",
        amount_delta_cents: amount_cents,
        reason_code: reason_code,
        source: line,
        notes: line.open_ring_description,
        audit_event_name: "stored_value.ledger.issued"
      )

      record_audit!(line, entry, amount_cents)
      entry
    end

    def resolve_line_account!(line)
      return if line.stored_value_account_id.present?

      result = GiftCardSaleAccountResolver.resolve!(
        transaction:,
        actor:,
        stored_value_account_id: line.stored_value_account_id,
        stored_value_identifier_id: line.stored_value_identifier_id,
        generate_identifier: line.generate_stored_value_identifier?
      )
      line.update!(
        stored_value_account: result.account,
        stored_value_identifier: result.identifier
      )
      line.reload
    end

    def ensure_identifier!(line)
      return if line.stored_value_identifier_id.present?
      return unless line.generate_stored_value_identifier?

      generated = GenerateStoredValueIdentifier.call_for_line!(line:, actor:, store: store)
      @generated_identifiers << generated
    end

    def record_audit!(line, entry, amount_cents)
      AuditEvents.record!(
        actor: actor,
        event_name: "pos.gift_card.sold",
        auditable: entry,
        source: transaction,
        details: {
          "store_id" => store.id,
          "pos_transaction_id" => transaction.id,
          "pos_transaction_line_id" => line.id,
          "stored_value_account_id" => line.stored_value_account_id,
          "amount_cents" => amount_cents,
          "balance_after_cents" => entry.balance_after_cents,
          "reload" => line.reload_gift_card_sale?
        }
      )

      AuditEvents.record!(
        actor: actor,
        event_name: "pos.stored_value.issued",
        auditable: entry,
        source: transaction,
        details: {
          "store_id" => store.id,
          "pos_transaction_id" => transaction.id,
          "pos_transaction_line_id" => line.id,
          "stored_value_account_id" => line.stored_value_account_id,
          "amount_cents" => amount_cents,
          "balance_after_cents" => entry.balance_after_cents
        }
      )
    end
  end
end
