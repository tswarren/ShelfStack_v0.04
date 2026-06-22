# frozen_string_literal: true

module Pos
  class SettlementSync
    Error = Class.new(StandardError)
    Result = Data.define(:change_cents, :remaining_cents, :message)

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
      Pos::RecalculateTransaction.call!(transaction) if transaction.total_cents.zero? && transaction.pos_transaction_lines.any?

      parser = SettlementInputParser.new(transaction:, raw_inputs: normalized_inputs)
      parsed_rows = parser.parse

      change_cents = 0
      remaining_cents = 0

      transaction.transaction do
        if parser.legacy_input?
          change_cents, remaining_cents = sync_legacy_rows!(parsed_rows)
        else
          change_cents, remaining_cents = sync_settlement_rows!(parsed_rows)
        end

        record_sync_audit!(parsed_rows)
      end

      Result.new(
        change_cents: change_cents,
        remaining_cents: remaining_cents,
        message: build_message(change_cents, remaining_cents)
      )
    end

    private

    attr_reader :transaction, :tender_inputs, :actor

    def normalized_inputs
      return tender_inputs if tender_inputs.present?

      []
    end

    def sync_legacy_rows!(parsed_rows)
      active_rows = parsed_rows.reject(&:destroy)
      transaction.pos_tenders.settlement_rows.where(tender_type: PosTender::PHASE6_ALLOWED_TYPES).destroy_all

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
        raise Error, "#{row.tender_type.humanize} refund must be negative on returns." if row.tender_type != "cash" && !row.amount_cents.negative?
        validate_card_row!(row)
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

      attrs = row_attributes(row, amount_cents:, tendered_cents:, change_cents:)
      if row.id.present?
        tender = transaction.pos_tenders.settlement_rows.find(row.id)
        tender.update!(attrs)
        tender
      else
        transaction.pos_tenders.create!(attrs.merge(line_number: PosTender.next_line_number_for(transaction)))
      end
    end

    def create_row_from_parsed!(row, amount_cents:, tendered_cents: nil, change_cents: nil)
      validate_row_type!(row)
      validate_card_row!(row)

      transaction.pos_tenders.create!(
        row_attributes(row, amount_cents:, tendered_cents:, change_cents:).merge(
          line_number: PosTender.next_line_number_for(transaction)
        )
      )
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
        reference_number: nil
      }
    end

    def validate_row_type!(row)
      unless PosTender::PHASE6_ALLOWED_TYPES.include?(row.tender_type)
        raise Error, "Tender type #{row.tender_type} is not enabled in Phase 7B-1."
      end
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
