# frozen_string_literal: true

module Pos
  class CommandBarRouter
    RECEIPT_NUMBER_PATTERN = /\A\d+-\d+-\d{6}\z/

    Route = Data.define(:action, :payload, :message)

    def self.call(store:, input:, return_mode: false)
      new(store:, input:, return_mode:).call
    end

    def initialize(store:, input:, return_mode: false)
      @store = store
      @input = input.to_s.strip
      @return_mode = return_mode
    end

    def call
      return Route.new(action: :empty, payload: {}, message: "Enter a SKU, ISBN, receipt number, or amount.") if input.blank?

      if lookup.variants.any?
        return Route.new(
          action: :variant_lookup,
          payload: { status: lookup.status, variants: lookup.variants },
          message: lookup.message
        )
      end

      if receipt_number?
        return Route.new(
          action: :receipt_lookup,
          payload: { transaction_number: input },
          message: nil
        )
      end

      if numeric_amount?
        return Route.new(
          action: :open_ring_offer,
          payload: { amount_cents: (BigDecimal(input) * 100).round.to_i },
          message: nil
        )
      end

      Route.new(
        action: :open_ring_offer,
        payload: { query: input },
        message: "No match found. Open-ring this item?"
      )
    end

    private

    attr_reader :store, :input, :return_mode

    def receipt_number?
      input.match?(RECEIPT_NUMBER_PATTERN)
    end

    def lookup
      @lookup ||= LineLookup.call(store: store, query: input)
    end

    def numeric_amount?
      return false if barcode_like_input?

      input.match?(/\A\d+(\.\d{1,2})?\z/)
    end

    def barcode_like_input?
      CatalogIdentifierService.lookup_digit_prefix(input).length >= 10
    end
  end
end
