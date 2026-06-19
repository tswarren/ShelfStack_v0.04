# frozen_string_literal: true

module Pos
  module ReportTransactionMetrics
    LineMetrics = Data.define(
      :sales_cents,
      :refunds_cents,
      :line_discount_cents,
      :order_discount_cents,
      :net_sales_cents,
      :taxes_cents,
      :units_sold,
      :no_receipt_return_lines
    )

    module_function

    def from_transaction(transaction)
      sales_cents = 0
      refunds_cents = 0
      line_discount_cents = 0
      order_discount_cents = 0
      net_sales_cents = 0
      units_sold = 0
      no_receipt_return_lines = 0

      transaction.pos_transaction_lines.each do |line|
        list_amount = line.unit_price_cents * line.quantity.abs
        line_discount_cents += line.line_discount_cents.to_i
        order_discount_cents += line.transaction_discount_cents.to_i

        if line.quantity.positive?
          sales_cents += list_amount
          net_sales_cents += line.extended_price_cents
          units_sold += line.quantity
        else
          refunds_cents -= list_amount
          net_sales_cents -= line.extended_price_cents
          if line.return_line? && line.source_transaction_line_id.blank?
            no_receipt_return_lines += 1
          end
        end
      end

      net_sales_cents += transaction.rounding_cents.to_i

      LineMetrics.new(
        sales_cents: sales_cents,
        refunds_cents: refunds_cents,
        line_discount_cents: line_discount_cents,
        order_discount_cents: order_discount_cents,
        net_sales_cents: net_sales_cents,
        taxes_cents: transaction.tax_cents.to_i,
        units_sold: units_sold,
        no_receipt_return_lines: no_receipt_return_lines
      )
    end

    def combine(metrics_list)
      metrics_list.reduce(empty) do |total, metrics|
        LineMetrics.new(
          sales_cents: total.sales_cents + metrics.sales_cents,
          refunds_cents: total.refunds_cents + metrics.refunds_cents,
          line_discount_cents: total.line_discount_cents + metrics.line_discount_cents,
          order_discount_cents: total.order_discount_cents + metrics.order_discount_cents,
          net_sales_cents: total.net_sales_cents + metrics.net_sales_cents,
          taxes_cents: total.taxes_cents + metrics.taxes_cents,
          units_sold: total.units_sold + metrics.units_sold,
          no_receipt_return_lines: total.no_receipt_return_lines + metrics.no_receipt_return_lines
        )
      end
    end

    def empty
      LineMetrics.new(
        sales_cents: 0,
        refunds_cents: 0,
        line_discount_cents: 0,
        order_discount_cents: 0,
        net_sales_cents: 0,
        taxes_cents: 0,
        units_sold: 0,
        no_receipt_return_lines: 0
      )
    end

    def total_discounts_cents(metrics)
      -(metrics.line_discount_cents + metrics.order_discount_cents)
    end

    def total_sales_cents(metrics)
      metrics.net_sales_cents + metrics.taxes_cents
    end

    def compact_hour_label(hour)
      start_time = Time.zone.local(2000, 1, 1, hour, 0)
      end_time = start_time + 1.hour
      "#{format_compact_hour(start_time)}–#{format_compact_hour(end_time)}"
    end

    def format_compact_hour(time)
      hour = time.strftime("%-I").to_i
      suffix = time.strftime("%p").downcase
      "#{hour}#{suffix}"
    end
  end
end
