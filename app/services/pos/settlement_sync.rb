# frozen_string_literal: true

module Pos
  class SettlementSync
    Error = Class.new(StandardError)
    Result = Data.define(:change_cents, :remaining_cents, :message, :generated_identifiers)

    def self.call!(transaction:, tender_inputs:, actor: nil)
      new(transaction:, tender_inputs:, actor:).call!
    end

    def self.tendered_cents_for(tender)
      return 0 if tender.blank?

      tender.tendered_display_cents
    end

    def self.preview_sale_totals(transaction, parsed_rows)
      non_cash = parsed_rows.reject { |row| row.destroy || row.tender_type == "cash" }
      cash_rows = parsed_rows.reject { |row| row.destroy || row.tender_type != "cash" }
      non_cash_sum = non_cash.sum(&:amount_cents)
      return nil if non_cash_sum > transaction.total_cents

      remaining = transaction.total_cents - non_cash_sum
      cash = cash_rows.first
      return transaction.total_cents if remaining.zero?
      return nil if cash.blank?

      tendered = cash.tendered_cents || cash.amount_cents
      return nil if tendered < remaining

      transaction.total_cents
    end

    def initialize(transaction:, tender_inputs:, actor: nil)
      @transaction = transaction
      @tender_inputs = tender_inputs
      @actor = actor
    end

    def call!
      @generated_identifiers = []
      if transaction.pos_transaction_lines.any?
        Pos::RecalculateTransaction.call!(transaction)
        @allowed_tender_types = nil
      end

      parser = SettlementInputParser.new(transaction:, raw_inputs: normalized_inputs)
      parsed_rows = parser.parse

      change_cents = 0
      remaining_cents = 0
      generated_identifiers = []

      transaction.transaction do
        if parser.legacy_input?
          change_cents, remaining_cents = sync_legacy_rows!(parsed_rows)
        else
          change_cents, remaining_cents = sync_settlement_rows!(parsed_rows)
        end

        record_sync_audit!(parsed_rows)
        generated_identifiers = @generated_identifiers
      end

      Result.new(
        change_cents: change_cents,
        remaining_cents: remaining_cents,
        message: build_message(change_cents, remaining_cents),
        generated_identifiers: generated_identifiers
      )
    end

    private

    attr_reader :transaction, :tender_inputs, :actor

    def normalized_inputs
      return [] if tender_inputs.blank?

      inputs = tender_inputs
      if inputs.respond_to?(:to_unsafe_h)
        hash = inputs.to_unsafe_h
        if hash.keys.all? { |key| key.to_s.match?(/\A\d+\z/) }
          return hash.sort_by { |key, _| key.to_i }.map { |_, value| value }
        end
      end

      Array(inputs)
    end

    def sync_legacy_rows!(parsed_rows)
      active_rows = parsed_rows.reject(&:destroy)
      transaction.pos_tenders.settlement_rows.where(tender_type: allowed_tender_types).destroy_all

      if transaction.total_cents.positive?
        sync_sale_legacy!(active_rows)
      elsif transaction.total_cents.negative?
        sync_return_legacy!(active_rows)
      else
        sync_zero_legacy!(active_rows)
      end
    end

    def sync_settlement_rows!(parsed_rows)
      parsed_rows.select(&:destroy).each do |row|
        destroy_row!(row)
      end

      active_rows = parsed_rows.reject(&:destroy)

      if transaction.total_cents.positive?
        sync_sale_rows!(active_rows)
      elsif transaction.total_cents.negative?
        sync_return_rows!(active_rows)
      else
        sync_zero_rows!(active_rows)
      end
    end

    def sync_sale_legacy!(rows)
      non_cash = rows.reject { |row| row.tender_type == "cash" }
      cash = rows.find { |row| row.tender_type == "cash" }
      non_cash_sum = non_cash.sum(&:amount_cents)
      raise Error, "Non-cash tenders exceed transaction total." if non_cash_sum > transaction.total_cents

      non_cash.each { |row| create_row_from_parsed!(row, amount_cents: row.amount_cents) }

      remaining = transaction.total_cents - non_cash_sum
      return [ 0, 0 ] if remaining.zero?
      raise Error, "Add a cash tender for the remaining #{format_money(remaining)}." if cash.blank?

      tendered = cash.tendered_cents || cash.amount_cents
      raise Error, "Insufficient cash tendered (#{format_money(tendered)}; #{format_money(remaining)} due)." if tendered < remaining

      change = tendered - remaining
      create_row_from_parsed!(cash, amount_cents: remaining, tendered_cents: tendered, change_cents: change.positive? ? change : nil)
      [ change, 0 ]
    end

    def sync_sale_rows!(rows)
      cash_rows = rows.select { |row| row.tender_type == "cash" }
      raise Error, "Only one cash settlement row is allowed." if cash_rows.size > 1

      non_cash = rows.reject { |row| row.tender_type == "cash" }
      cash = cash_rows.first
      non_cash_sum = non_cash.sum(&:amount_cents)
      raise Error, "Non-cash tenders exceed transaction total." if non_cash_sum > transaction.total_cents

      non_cash.each { |row| upsert_row!(row, amount_cents: row.amount_cents) }

      remaining = transaction.total_cents - non_cash_sum
      return [ 0, remaining ] if remaining.zero?
      raise Error, "Add a cash tender for the remaining #{format_money(remaining)}." if cash.blank?

      tendered = cash.tendered_cents || cash.amount_cents
      raise Error, "Insufficient cash tendered (#{format_money(tendered)}; #{format_money(remaining)} due)." if tendered < remaining

      change = tendered - remaining
      upsert_row!(cash, amount_cents: remaining, tendered_cents: tendered, change_cents: change.positive? ? change : nil)
      [ change, 0 ]
    end

    def sync_return_legacy!(rows)
      validate_return_rows!(rows)
      rows.each { |row| create_row_from_parsed!(row, amount_cents: row.amount_cents) }
      validate_tender_total!
      [ 0, 0 ]
    end

    def sync_return_rows!(rows)
      validate_return_rows!(rows)
      rows.each { |row| upsert_row!(row, amount_cents: row.amount_cents) }
      validate_tender_total!
      [ 0, 0 ]
    end

    def sync_zero_legacy!(rows)
      rows.each { |row| create_row_from_parsed!(row, amount_cents: row.amount_cents) }
      validate_tender_total!
      [ 0, 0 ]
    end

    def sync_zero_rows!(rows)
      rows.each { |row| upsert_row!(row, amount_cents: row.amount_cents) }
      validate_tender_total!
      [ 0, 0 ]
    end

    def validate_return_rows!(rows)
      rows.each do |row|
        raise Error, "Cash refund must be negative on returns." if row.tender_type == "cash" && !row.amount_cents.negative?
        raise Error, "Check refunds are not supported." if row.tender_type == "check"
        if Pos::StoredValueTenderSupport.stored_value_tender?(row.tender_type) && !row.amount_cents.negative?
          raise Error, "#{row.tender_type.humanize} refund must be negative on returns."
        end
        if !Pos::StoredValueTenderSupport.stored_value_tender?(row.tender_type) &&
            row.tender_type != "cash" && !row.amount_cents.negative?
          raise Error, "#{row.tender_type.humanize} refund must be negative on returns."
        end
        validate_card_row!(row)
        validate_stored_value_row!(row)
      end
    end

    def validate_tender_total!
      total = transaction.pos_tenders.settlement_rows.sum(:amount_cents)
      return if total == transaction.total_cents

      raise Error, "Tender total does not match transaction total."
    end

    def upsert_row!(row, amount_cents:, tendered_cents: nil, change_cents: nil)
      validate_row_type!(row)
      validate_card_row!(row)
      row = prepare_stored_value_row!(row)

      attrs = row_attributes(row, amount_cents:, tendered_cents:, change_cents:)
      tender = if row.id.present?
        record = transaction.pos_tenders.settlement_rows.find(row.id)
        record.update!(attrs)
        record
      else
        transaction.pos_tenders.create!(attrs.merge(line_number: PosTender.next_line_number_for(transaction)))
      end
      maybe_generate_stored_value_identifier!(tender)
    end

    def create_row_from_parsed!(row, amount_cents:, tendered_cents: nil, change_cents: nil)
      validate_row_type!(row)
      validate_card_row!(row)
      row = prepare_stored_value_row!(row)

      tender = transaction.pos_tenders.create!(
        row_attributes(row, amount_cents:, tendered_cents:, change_cents:).merge(
          line_number: PosTender.next_line_number_for(transaction)
        )
      )
      maybe_generate_stored_value_identifier!(tender)
    end

    def destroy_row!(row)
      return if row.id.blank?

      transaction.pos_tenders.settlement_rows.find_by(id: row.id)&.destroy!
    end

    def row_attributes(row, amount_cents:, tendered_cents:, change_cents:)
      {
        tender_type: row.tender_type,
        amount_cents: amount_cents,
        tendered_cents: tendered_cents,
        change_cents: change_cents,
        card_brand: row.tender_type == "card" ? (row.card_brand || "other") : nil,
        card_last_four: row.card_last_four,
        card_authorization_code: row.card_authorization_code,
        check_number: row.check_number,
        notes: row.notes,
        stored_value_account_id: row.stored_value_account_id,
        stored_value_identifier_id: row.stored_value_identifier_id,
        generate_stored_value_identifier: row.generate_identifier == true,
        reference_number: nil
      }
    end

    def validate_row_type!(row)
      return if allowed_tender_types.include?(row.tender_type)

      raise Error, stored_value_tender_disabled_message(row.tender_type)
    end

    def stored_value_tender_disabled_message(tender_type)
      return "Tender type #{tender_type} is not enabled." unless Pos::StoredValueTenderSupport.stored_value_tender?(tender_type)
      return "Tender type #{tender_type} is not enabled." if actor.blank?

      if TenderTypePolicy.refund_transaction?(transaction)
        "Store credit refunds are not enabled for your role."
      else
        "Stored value tender #{tender_type} is not enabled for your role."
      end
    end

    def validate_stored_value_row!(row)
      return unless Pos::StoredValueTenderSupport.stored_value_tender?(row.tender_type)

      if row.stored_value_account_id.blank? && row.lookup_code.blank? &&
          transaction.customer_id.blank? && !row.generate_identifier
        raise Error, "Stored value account or lookup code is required."
      end
    end

    def maybe_generate_stored_value_identifier!(tender)
      return unless tender.generate_stored_value_identifier?
      return if tender.stored_value_identifier_id.present?
      return unless tender.issue_tender?(transaction)
      raise Error, "Actor is required to generate stored value identifiers." if actor.blank?

      generated = GenerateStoredValueIdentifier.call!(tender:, actor:, store: transaction.store)
      @generated_identifiers << generated
    end

    def allowed_tender_types
      @allowed_tender_types ||= if actor.present?
        TenderTypePolicy.allowed_types(transaction, actor:, store: transaction.store)
      else
        PosTender::PHASE6_ALLOWED_TYPES
      end
    end

    def prepare_stored_value_row!(row)
      return row unless Pos::StoredValueTenderSupport.stored_value_tender?(row.tender_type)
      return row if row.stored_value_account_id.present? && row.lookup_code.blank?
      raise Error, "Actor is required to resolve stored value accounts." if actor.blank?

      result = StoredValueAccountResolver.resolve!(
        transaction:,
        tender_type: row.tender_type,
        actor:,
        stored_value_account_id: row.stored_value_account_id,
        lookup_code: row.lookup_code,
        generate_identifier: row.generate_identifier == true
      )

      row.with(
        stored_value_account_id: result.account.id.to_s,
        stored_value_identifier_id: result.identifier&.id&.to_s
      )
    end

    def validate_card_row!(row)
      return unless row.tender_type == "card"
      return if row.card_brand.present?

      raise Error, "Card brand is required for card tenders."
    end

    def record_sync_audit!(parsed_rows)
      return if actor.blank?

      AuditEvents.record!(
        actor: actor,
        event_name: "pos.settlement.synced",
        auditable: transaction,
        details: {
          "row_count" => transaction.pos_tenders.settlement_rows.count,
          "input_count" => parsed_rows.size,
          "total_cents" => transaction.total_cents
        }
      )
    end

    def build_message(change_cents, remaining_cents)
      if change_cents.positive?
        "Change due: #{format_money(change_cents)}."
      elsif remaining_cents.positive?
        "Remaining due: #{format_money(remaining_cents)}."
      end
    end

    def format_money(cents)
      format("$%.2f", cents / 100.0)
    end
  end
end
