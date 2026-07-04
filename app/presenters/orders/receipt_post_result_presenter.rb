# frozen_string_literal: true

module Orders
  class ReceiptPostResultPresenter
    include Rails.application.routes.url_helpers

    ShortRow = Data.define(:demand_line, :variant, :quantity, :reason)

    def initialize(receipt:, document_hub:)
      @receipt = receipt
      @document_hub = document_hub
      @impact = Receiving::ReceiptDemandImpactPreview.call(receipt: receipt)
    end

    attr_reader :receipt, :document_hub, :impact

    def inventory_increase
      receipt.receipt_lines.sum(&:quantity_accepted)
    end

    def customer_ready_rows
      impact.customer_ready_rows.filter_map do |row|
        next if row.demand_line.blank?

        {
          customer_name: row.demand_line.display_customer_name,
          variant: row.demand_line.product_variant,
          demand_number: row.demand_line.demand_number,
          demand_line: row.demand_line,
          needed_by: nil,
          contact_hint: row.demand_line.customer&.phone.presence || row.demand_line.customer&.email,
          quantity: row.quantity
        }
      end
    end

    def shelf_rows
      impact.shelf_rows.group_by { |row| row.demand_line&.product_variant || row.demand_line }
             .map do |variant, rows|
        {
          variant: variant.is_a?(ProductVariant) ? variant : rows.first&.demand_line&.product_variant,
          quantity: rows.sum(&:quantity)
        }
      end.select { |row| row[:quantity].positive? }
    end

    def short_rows
      adapter_views = Receiving::ReceiptPostingMatchAdapter.call(receipt: receipt)
      rows = []
      adapter_views.each do |view|
        next if view.purchase_order_line.blank?

        planned = view.purchase_order_line.purchase_order_line_demand_plans.active_plans.sum(:quantity_planned)
        matched = view.quantity_accepted
        short = [ planned - matched, 0 ].max
        next if short.zero?

        view.purchase_order_line.purchase_order_line_demand_plans.active_plans.each do |plan|
          rows << ShortRow.new(
            demand_line: plan.demand_line,
            variant: plan.product_variant,
            quantity: short,
            reason: "Receipt did not cover planned quantity"
          )
        end
      end
      rows.uniq { |r| r.demand_line.id }
    end

    def show_short_section?
      short_rows.any?
    end
  end
end
