# frozen_string_literal: true

class BackfillPhase853aOrderingReadiness < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    say_with_time "Backfill purchase order line economics metadata" do
      PurchaseOrderLine.reset_column_information
      PurchaseOrderLine.find_each do |line|
        variant = ProductVariant.find_by(id: line.product_variant_id)
        retail = variant&.selling_price_cents
        cost = line.unit_cost_cents
        qty = line.quantity_ordered.to_i
        line_cost = cost.present? ? cost * qty : nil
        line_retail = retail.present? ? retail * qty : nil
        margin = line_retail.present? && line_cost.present? ? line_retail - line_cost : nil
        margin_bps = if line_retail.present? && line_retail.positive? && margin.present?
          ((margin.to_f / line_retail) * 10_000).round
        end

        line.update_columns(
          expected_retail_price_cents: retail,
          expected_line_cost_cents: line_cost,
          expected_line_retail_cents: line_retail,
          expected_margin_cents: margin,
          expected_margin_bps: margin_bps,
          cost_source: "unknown",
          price_source: retail.present? ? "variant" : "unknown",
          updated_at: Time.current
        )
      end
    end

    say_with_time "Backfill product variant orderable defaults" do
      ProductVariant.reset_column_information
      ProductVariant.includes(:product, :condition).find_each do |variant|
        orderable = ProductVariants::OrderabilityDefaults.resolve(variant)
        variant.update_columns(orderable: orderable, updated_at: Time.current)
      end
    end
  end

  def down
    # no-op
  end
end
