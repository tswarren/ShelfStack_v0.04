# frozen_string_literal: true

module Reports
  module InventoryValue
    DepartmentRow = Data.define(:department_name, :quantity_on_hand, :cost_cents, :retail_cents)
    Result = Data.define(:store_totals, :department_rows, :enterprise_rows, :metrics)

    class Query
      def self.call(store:, include_enterprise: false)
        new(store: store, include_enterprise: include_enterprise).call
      end

      def initialize(store:, include_enterprise: false)
        @store = store
        @include_enterprise = include_enterprise
      end

      def call
        totals = Inventory::Valuation.store_totals(store: store)

        department_rows = InventoryBalance.where(store: store)
          .joins(product_variant: { sub_department: :department })
          .group("departments.name")
          .pluck(
            "departments.name",
            Arel.sql("SUM(quantity_on_hand)"),
            Arel.sql("SUM(inventory_cost_value_cents)"),
            Arel.sql("SUM(inventory_retail_value_cents)")
          )
          .map do |name, qty, cost, retail|
            DepartmentRow.new(
              department_name: name,
              quantity_on_hand: qty.to_i,
              cost_cents: cost.to_i,
              retail_cents: retail.to_i
            )
          end
          .sort_by(&:department_name)

        enterprise_rows = if include_enterprise
          Store.active_records.order(:store_number).map do |other_store|
            other_totals = Inventory::Valuation.store_totals(store: other_store)
            [ other_store.name, other_totals ]
          end
        else
          []
        end

        Result.new(
          store_totals: totals,
          department_rows: department_rows,
          enterprise_rows: enterprise_rows,
          metrics: [
            { label: "On hand", value: totals[:quantity_on_hand] },
            { label: "Cost value", value_cents: totals[:inventory_cost_value_cents] },
            { label: "Retail value", value_cents: totals[:inventory_retail_value_cents] }
          ]
        )
      end

      private

      attr_reader :store, :include_enterprise
    end
  end
end
