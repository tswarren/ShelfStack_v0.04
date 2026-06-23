# frozen_string_literal: true

module Pos
  class UpdateGiftCardSaleLine
    Error = Class.new(StandardError)

    def self.call!(line:, actor:, lookup_code: nil, clear_card_number: false, generate_identifier: nil, unit_price_cents: nil)
      new(
        line:,
        actor:,
        lookup_code:,
        clear_card_number:,
        generate_identifier:,
        unit_price_cents:
      ).call!
    end

    def initialize(line:, actor:, lookup_code: nil, clear_card_number: false, generate_identifier: nil, unit_price_cents: nil)
      @line = line
      @actor = actor
      @lookup_code = lookup_code&.strip.presence
      @clear_card_number = clear_card_number
      @generate_identifier = generate_identifier
      @unit_price_cents = unit_price_cents
    end

    def call!
      raise Error, "Line is not a gift card sale." unless GiftCardSaleSupport.gift_card_sale_line?(line)
      raise Error, "Transaction is not editable." unless line.pos_transaction.editable?
      authorize!

      attrs = {}
      if unit_price_cents.present?
        attrs[:unit_price_cents] = GiftCardSaleSupport.validate_amount!(unit_price_cents)
      end

      if clear_card_number
        attrs.merge!(
          stored_value_account_id: nil,
          stored_value_identifier_id: nil,
          generate_stored_value_identifier: true
        )
      elsif lookup_code.present?
        result = resolve_sale_account!
        attrs.merge!(
          stored_value_account_id: result.account.id,
          stored_value_identifier_id: result.identifier.id,
          generate_stored_value_identifier: false
        )
      elsif !generate_identifier.nil?
        attrs[:generate_stored_value_identifier] = ActiveModel::Type::Boolean.new.cast(generate_identifier)
        if attrs[:generate_stored_value_identifier]
          attrs[:stored_value_account_id] = nil
          attrs[:stored_value_identifier_id] = nil
        end
      end

      line.update!(attrs) if attrs.any?
      RecalculateTransaction.call!(line.pos_transaction.reload)
      line.reload
    end

    private

    attr_reader :line, :actor, :lookup_code, :clear_card_number, :generate_identifier, :unit_price_cents

    def authorize!
      return if GiftCardSalePolicy.issue_permitted?(actor:, store: line.pos_transaction.store)

      raise Error, "You are not authorized to sell gift cards at POS."
    end

    def resolve_sale_account!
      GiftCardSaleAccountResolver.resolve_for_sale!(
        transaction: line.pos_transaction,
        actor: actor,
        lookup_code: lookup_code
      )
    rescue GiftCardSaleAccountResolver::Error => e
      raise Error, e.message
    end
  end
end
