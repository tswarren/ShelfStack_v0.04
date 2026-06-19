# frozen_string_literal: true

module Pos
  class TenderSync
    Error = Class.new(StandardError)
    Result = Data.define(:change_cents, :message)

    TENDERED_REFERENCE_PREFIX = "tendered_cents:"

    def self.call!(transaction:, tender_inputs:)
      new(transaction:, tender_inputs:).call!
    end

    def self.tendered_cents_for(tender)
      return tender.amount_cents if tender.blank?
      return tender.amount_cents unless tender.reference_number.to_s.start_with?(TENDERED_REFERENCE_PREFIX)

      tender.reference_number.delete_prefix(TENDERED_REFERENCE_PREFIX).to_i
    end

    def initialize(transaction:, tender_inputs:)
      @transaction = transaction
      @tender_inputs = Array(tender_inputs)
    end

    def call!
      Pos::RecalculateTransaction.call!(transaction) if transaction.total_cents.zero? && transaction.pos_transaction_lines.any?

      transaction.pos_tenders.destroy_all
      change_cents = 0

      if transaction.total_cents.positive?
        change_cents = sync_sale_tenders!
      elsif transaction.total_cents.negative?
        sync_return_tenders!
      else
        sync_exact_tenders!
      end

      Result.new(
        change_cents: change_cents,
        message: change_cents.positive? ? "Change due: #{format_money(change_cents)}." : nil
      )
    end

    private

    attr_reader :transaction, :tender_inputs

    def sync_sale_tenders!
      parsed = parse_inputs
      non_cash = parsed.reject { |t| t[:tender_type] == "cash" }
      cash = parsed.find { |t| t[:tender_type] == "cash" }

      non_cash_sum = non_cash.sum { |t| t[:amount_cents] }
      raise Error, "Non-cash tenders exceed transaction total." if non_cash_sum > transaction.total_cents

      non_cash.each { |t| create_tender!(t[:tender_type], t[:amount_cents]) }

      remaining = transaction.total_cents - non_cash_sum
      return 0 if remaining.zero?
      raise Error, "Add a cash tender for the remaining #{format_money(remaining)}." if cash.blank?

      tendered = cash[:amount_cents]
      raise Error, "Insufficient cash tendered (#{format_money(tendered)}; #{format_money(remaining)} due)." if tendered < remaining

      change = tendered - remaining
      create_tender!("cash", remaining, tendered_cents: tendered)
      change
    end

    def sync_return_tenders!
      parsed = parse_inputs
      total_due = transaction.total_cents.abs

      parsed.each do |t|
        amount = t[:amount_cents]
        if t[:tender_type] == "cash"
          raise Error, "Cash refund must be negative on returns." unless amount.negative?
          raise Error, "Cash refund (#{format_money(amount.abs)}) does not match amount due (#{format_money(total_due)})." if amount.abs != total_due
        else
          raise Error, "#{t[:tender_type].humanize} refund must be negative on returns." unless amount.negative?
          raise Error, "Tender amount does not match amount due." if amount.abs > total_due
        end

        create_tender!(t[:tender_type], amount)
      end

      tender_total = transaction.pos_tenders.sum(&:amount_cents)
      raise Error, "Tender total does not match transaction total." if tender_total != transaction.total_cents

      0
    end

    def sync_exact_tenders!
      parsed = parse_inputs
      parsed.each { |t| create_tender!(t[:tender_type], t[:amount_cents]) }

      tender_total = transaction.pos_tenders.sum(&:amount_cents)
      raise Error, "Tender total does not match transaction total." if tender_total != transaction.total_cents

      0
    end

    def parse_inputs
      tender_inputs.filter_map do |attrs|
        amount_cents = if attrs[:amount_dollars].present?
          parse_dollar_cents(attrs[:amount_dollars])
        else
          attrs[:amount_cents].to_i
        end

        next if amount_cents.zero?

        {
          tender_type: attrs[:tender_type],
          amount_cents: amount_cents,
          reference_number: attrs[:reference_number]
        }
      end
    end

    def create_tender!(tender_type, amount_cents, tendered_cents: nil)
      reference_number = if tendered_cents.present? && tendered_cents > amount_cents
                           "#{TENDERED_REFERENCE_PREFIX}#{tendered_cents}"
                         end

      transaction.pos_tenders.create!(
        tender_type: tender_type,
        amount_cents: amount_cents,
        reference_number: reference_number
      )
    end

    def parse_dollar_cents(value)
      (BigDecimal(value.to_s) * 100).round.to_i
    end

    def format_money(cents)
      format("$%.2f", cents / 100.0)
    end
  end
end
