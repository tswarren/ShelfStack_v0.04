# frozen_string_literal: true

module Receiving
  class ReceiptPostingMatchAdapter
    LineView = Data.define(
      :receipt_line,
      :purchase_order_line,
      :quantity_accepted
    )

    def self.call(receipt:)
      new(receipt:).call
    end

    def initialize(receipt:)
      @receipt = receipt
    end

    def call
      views = []
      receipt.receipt_lines.each do |receipt_line|
        next if receipt_line.quantity_accepted.zero?

        matched_groups = confirmed_matches_for(receipt_line)
        if matched_groups.any?
          matched_groups.each do |match|
            views << LineView.new(
              receipt_line: receipt_line,
              purchase_order_line: match.purchase_order_line,
              quantity_accepted: match.quantity_matched
            )
          end
        elsif receipt_line.purchase_order_line.present?
          views << LineView.new(
            receipt_line: receipt_line,
            purchase_order_line: receipt_line.purchase_order_line,
            quantity_accepted: receipt_line.quantity_accepted
          )
        end
      end
      views
    end

    private

    attr_reader :receipt

    def confirmed_matches_for(receipt_line)
      ReceiptLineMatch.confirmed_matches
                      .where(receipt_line: receipt_line)
                      .includes(:purchase_order_line)
    end
  end
end
