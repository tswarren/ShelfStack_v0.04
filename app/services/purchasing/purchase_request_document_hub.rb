# frozen_string_literal: true

module Purchasing
  class PurchaseRequestDocumentHub
    RequestSummary = Data.define(:line_count, :buildable_line_count, :added_line_count)
    LineRow = Data.define(
      :purchase_request_line,
      :purchase_order_line,
      :purchase_order
    )
    PurchaseOrderLink = Data.define(:purchase_order, :line_count)

    Result = Data.define(
      :summary,
      :lines,
      :purchase_orders,
      :buildable
    )

    def self.call(purchase_request)
      new(purchase_request).call
    end

    def initialize(purchase_request)
      @purchase_request = purchase_request
    end

    def call
      line_rows = purchase_request.purchase_request_lines.map do |request_line|
        po_line = request_line.purchase_order_line
        LineRow.new(
          purchase_request_line: request_line,
          purchase_order_line: po_line,
          purchase_order: po_line&.purchase_order
        )
      end

      orders_by_id = {}
      line_rows.each do |row|
        next if row.purchase_order.blank?

        orders_by_id[row.purchase_order.id] ||= { purchase_order: row.purchase_order, count: 0 }
        orders_by_id[row.purchase_order.id][:count] += 1
      end

      Result.new(
        summary: summary,
        lines: line_rows,
        purchase_orders: orders_by_id.values.map do |entry|
          PurchaseOrderLink.new(purchase_order: entry[:purchase_order], line_count: entry[:count])
        end.sort_by { |entry| entry.purchase_order.created_at }.reverse,
        buildable: purchase_request.buildable?
      )
    end

    private

    attr_reader :purchase_request

    def summary
      lines = purchase_request.purchase_request_lines.to_a
      RequestSummary.new(
        line_count: lines.size,
        buildable_line_count: purchase_request.buildable_lines.size,
        added_line_count: lines.count { |line| line.status == "added_to_po" }
      )
    end
  end
end
