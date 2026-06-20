# frozen_string_literal: true

module Pos
  class DeriveTransactionType
    def self.call(transaction)
      new(transaction).call
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      signs = merchandise_lines.map { |line| line.quantity <=> 0 }.uniq
      return nil if signs.empty?

      if signs == [ 1 ]
        "sale"
      elsif signs == [ -1 ]
        "return"
      else
        "exchange"
      end
    end

    private

    attr_reader :transaction

    def merchandise_lines
      transaction.pos_transaction_lines.select do |line|
        line.merchandise_line? && !line.quantity.zero?
      end
    end
  end
end
