# frozen_string_literal: true

module Reports
  ReportDefinition = Data.define(:key, :name, :group, :path, :permission_key, :description)

  class Registry
    GROUPS = [
      "Sales",
      "Cash/Register",
      "Taxes",
      "Inventory",
      "Purchasing",
      "Buybacks",
      "Customers",
      "Stored Value"
    ].freeze

    REPORTS = [
      ReportDefinition.new(
        key: :sales_summary,
        name: "Sales & Revenue Summary",
        group: "Sales",
        path: :reports_sales_summary_path,
        permission_key: "pos.reports.summary",
        description: "Gross sales, returns, discounts, tax, and tender breakdown."
      ),
      ReportDefinition.new(
        key: :sales,
        name: "Sales List",
        group: "Sales",
        path: :reports_sales_path,
        permission_key: "pos.reports.sales",
        description: "Recent completed sale transactions."
      ),
      ReportDefinition.new(
        key: :returns,
        name: "Returns List",
        group: "Sales",
        path: :reports_returns_path,
        permission_key: "pos.reports.returns",
        description: "Recent return and exchange transactions."
      ),
      ReportDefinition.new(
        key: :operational_margin,
        name: "Operational Margin",
        group: "Sales",
        path: :reports_operational_margin_path,
        permission_key: "pos.reports.summary",
        description: "Sale-time COGS snapshots and margin by department."
      ),
      ReportDefinition.new(
        key: :register_summary,
        name: "Register Summary",
        group: "Cash/Register",
        path: :reports_register_summary_path,
        permission_key: "pos.reports.register_summary",
        description: "Session reconciliation for cash, tax, tenders, and exceptions."
      ),
      ReportDefinition.new(
        key: :cash_drawer,
        name: "Cash Drawer Activity",
        group: "Cash/Register",
        path: :reports_cash_drawer_path,
        permission_key: "pos.reports.drawer",
        description: "Register session cash movements and over/short."
      ),
      ReportDefinition.new(
        key: :tax_collected,
        name: "Tax Collected",
        group: "Taxes",
        path: :reports_tax_collected_path,
        permission_key: "pos.reports.summary",
        description: "Tax by category and rate with exemption and override summary."
      ),
      ReportDefinition.new(
        key: :discount_summary,
        name: "Discount Summary",
        group: "Taxes",
        path: :reports_discount_summary_path,
        permission_key: "pos.reports.summary",
        description: "Discount applications by reason and cashier."
      ),
      ReportDefinition.new(
        key: :inventory_value,
        name: "Inventory Value Snapshot",
        group: "Inventory",
        path: :reports_inventory_value_path,
        permission_key: "inventory.balances.view",
        description: "On-hand quantity and retail/cost value by department."
      ),
      ReportDefinition.new(
        key: :purchasing_summary,
        name: "Purchasing & Receiving Summary",
        group: "Purchasing",
        path: :reports_purchasing_summary_path,
        permission_key: "orders.access",
        description: "Purchase orders and receipt acceptance totals."
      ),
      ReportDefinition.new(
        key: :buyback_summary,
        name: "Buyback Summary",
        group: "Buybacks",
        path: :reports_buyback_summary_path,
        permission_key: "buybacks.reports.view",
        description: "Buyback sessions, payouts, and activity."
      ),
      ReportDefinition.new(
        key: :demand_queue,
        name: "Demand Queue",
        group: "Customers",
        path: :reports_demand_queue_path,
        permission_key: "demand.access",
        description: "Operational demand queues for pickup, sourcing, and fulfillment."
      ),
      ReportDefinition.new(
        key: :stored_value,
        name: "Stored Value Liability",
        group: "Stored Value",
        path: :reports_stored_value_path,
        permission_key: "stored_value.reports.view",
        description: "Gift card, store credit, and trade credit balances and activity."
      )
    ].freeze

    def self.all
      REPORTS
    end

    def self.find(key)
      REPORTS.find { |report| report.key == key.to_sym }
    end

    def self.permitted_for(user:, store:)
      REPORTS.select do |report|
        Authorization.allowed?(user: user, permission_key: report.permission_key, store: store)
      end
    end

    def self.nav_visible?(user:, store:)
      permitted_for(user: user, store: store).any?
    end

    def self.grouped_for(user:, store:)
      permitted = permitted_for(user: user, store: store)
      GROUPS.filter_map do |group|
        reports = permitted.select { |report| report.group == group }
        next if reports.empty?

        [ group, reports ]
      end.to_h
    end
  end
end
