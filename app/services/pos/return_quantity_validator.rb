# frozen_string_literal: true

module Pos
  class ReturnQuantityValidator
    Error = Class.new(StandardError)

    def self.call!(line)
      new(line).call!
    end

    def initialize(line)
      @line = line
    end

    def call!
      return if line.source_transaction_line_id.blank?
      return unless line.return_line?

      source_line = line.source_transaction_line
      raise Error, "Source sale line not found." if source_line.blank?
      raise Error, "Source sale line must be from a completed transaction." unless source_line.pos_transaction.completed?

      original_qty = source_line.quantity.abs
      already_returned = PosTransactionLine
        .joins(:pos_transaction)
        .where(source_transaction_line_id: source_line.id)
        .where(pos_transactions: { status: "completed" })
        .where.not(id: line.id)
        .sum(:quantity)
        .abs

      requested = line.quantity.abs
      if already_returned + requested > original_qty
        remaining = original_qty - already_returned
        raise Error, "Return quantity exceeds remaining sold quantity (#{remaining} remaining)."
      end
    end

    private

    attr_reader :line
  end
end
