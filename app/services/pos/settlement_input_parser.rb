# frozen_string_literal: true

module Pos
  class SettlementInputParser
    ParsedRow = Data.define(
      :id, :destroy, :tender_type, :amount_cents, :tendered_cents,
      :card_brand, :card_last_four, :card_authorization_code, :check_number, :notes,
      :stored_value_account_id, :stored_value_identifier_id, :lookup_code, :generate_identifier
    )

    def self.parse(transaction:, raw_inputs:)
      new(transaction:, raw_inputs:).parse
    end

    def self.normalize_refund_amount_cents(transaction, amount_cents)
      return amount_cents unless Pos::TenderTypePolicy.refund_transaction?(transaction)
      return amount_cents if amount_cents.negative?

      -amount_cents.abs
    end

    def initialize(transaction:, raw_inputs:)
      @transaction = transaction
      @raw_inputs = Array(raw_inputs)
    end

    def parse
      raw_inputs.filter_map do |attrs|
        normalize(attrs)
      end
    end

    def legacy_input?
      parse.all? { |row| row.id.blank? }
    end

    private

    attr_reader :transaction, :raw_inputs

    def normalize(attrs)
      attrs = normalize_attrs_hash(attrs)
      amount_cents = parse_amount_cents(attrs)
      tendered_cents = parse_tendered_cents(attrs)
      return if amount_cents.zero? && tendered_cents.nil? && !zero_total_input?(attrs, amount_cents) && !truthy?(attrs[:_destroy])

      amount_cents = self.class.normalize_refund_amount_cents(transaction, amount_cents)

      ParsedRow.new(
        id: attrs[:id].presence,
        destroy: truthy?(attrs[:_destroy]),
        tender_type: attrs[:tender_type],
        amount_cents: amount_cents,
        tendered_cents: tendered_cents,
        card_brand: attrs[:tender_type] == "card" ? (attrs[:card_brand].presence || "other") : attrs[:card_brand].presence,
        card_last_four: attrs[:card_last_four].presence,
        card_authorization_code: attrs[:card_authorization_code].presence,
        check_number: attrs[:check_number].presence,
        notes: attrs[:notes].presence,
        stored_value_account_id: attrs[:stored_value_account_id].presence,
        stored_value_identifier_id: attrs[:stored_value_identifier_id].presence,
        lookup_code: attrs[:lookup_code].presence,
        generate_identifier: parse_generate_identifier(attrs)
      )
    end

    def parse_amount_cents(attrs)
      if attrs[:amount_dollars].present?
        (BigDecimal(attrs[:amount_dollars].to_s) * 100).round.to_i
      else
        attrs[:amount_cents].to_i
      end
    end

    def parse_tendered_cents(attrs)
      return nil unless attrs[:tender_type] == "cash"

      if attrs[:tendered_dollars].present?
        (BigDecimal(attrs[:tendered_dollars].to_s) * 100).round.to_i
      elsif attrs[:tendered_cents].present?
        attrs[:tendered_cents].to_i
      elsif attrs[:tender_type] == "cash" && attrs[:amount_dollars].present?
        parse_amount_cents(attrs)
      end
    end

    def zero_total_input?(attrs, amount_cents)
      transaction.total_cents.zero? &&
        amount_cents.zero? &&
        (attrs[:amount_dollars].present? || attrs.key?(:amount_cents))
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def parse_generate_identifier(attrs)
      return false unless Pos::StoredValueTenderSupport.stored_value_tender?(attrs[:tender_type])
      return false unless Pos::TenderTypePolicy.refund_transaction?(transaction)

      truthy?(attrs[:generate_identifier])
    end

    def normalize_attrs_hash(attrs)
      raw = if attrs.respond_to?(:to_unsafe_h)
        attrs.to_unsafe_h
      elsif attrs.respond_to?(:to_h)
        attrs.to_h
      else
        attrs
      end

      raw.symbolize_keys
    end
  end
end
