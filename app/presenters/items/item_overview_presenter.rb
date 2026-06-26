# frozen_string_literal: true

module Items
  class ItemOverviewPresenter
    include Rails.application.routes.url_helpers

    SummaryCard = Data.define(:key, :label, :status, :detail, :severity)
    MatrixRow = Data.define(
      :variant,
      :snapshot,
      :warnings,
      :worst_severity,
      :vendor_source_status,
      :last_sold_at,
      :order_eligibility,
      :sub_department_name,
      :tax_category_name
    )
    ActivityCounts = Data.define(:open_tbo_lines, :open_po_lines, :recent_receipts, :open_requests)

    def self.for(item:, store:, user:)
      new(item:, store:, user:).build
    end

    def initialize(item:, store:, user:)
      @item = item
      @store = store
      @user = user
    end

    def build
      self
    end

    def warnings
      @warnings ||= OperationalWarningBuilder.for_item(
        item: item,
        store: store,
        user: user,
        contexts: OperationalWarningBuilder.default_contexts,
        snapshot: snapshot,
        eligibility_by_variant: order_eligibility
      ).fetch(item, [])
    end

    def warning_counts
      @warning_counts ||= OperationalWarningBuilder.counts_by_severity(warnings)
    end

    def worst_severity
      @worst_severity ||= OperationalWarningBuilder.worst_severity(warnings)
    end

    def summary_cards
      @summary_cards ||= [
        sell_card,
        order_card,
        stock_card,
        activity_card
      ]
    end

    def matrix_rows
      @matrix_rows ||= variants.map do |variant|
        row_snapshot = snapshot.rows[variant.id]
        row_warnings = warnings_by_variant[variant.id] || []
        suggested = row_snapshot&.suggested_vendor
        classification = classification_for(variant)
        MatrixRow.new(
          variant: variant,
          snapshot: row_snapshot,
          warnings: row_warnings,
          worst_severity: OperationalWarningBuilder.worst_severity(row_warnings),
          vendor_source_status: vendor_source_status(variant, suggested, row_snapshot),
          last_sold_at: last_sold_at[variant.id],
          order_eligibility: order_eligibility[variant.id],
          sub_department_name: variant.sub_department&.name,
          tax_category_name: classification.tax_category&.name
        )
      end
    end

    def sales_history_rows
      @sales_history_rows ||= sales_visible? ? SalesHistoryLookup.for_variants(store:, variant_ids: variant_ids, limit: 10) : []
    end

    def receiving_history_rows
      @receiving_history_rows ||= receiving_visible? ? ReceivingHistoryLookup.for_variants(store:, variant_ids: variant_ids, limit: 10) : []
    end

    def activity_counts
      @activity_counts ||= ActivityCounts.new(
        open_tbo_lines: snapshot.rows.values.sum(&:open_tbo),
        open_po_lines: open_po_line_count,
        recent_receipts: receiving_history_rows.size,
        open_requests: 0
      )
    end

    def inventory_visible?
      return false unless store.present? && user.present?

      Authorization.allowed?(user: user, permission_key: "inventory.access", store: store) &&
        Authorization.allowed?(user: user, permission_key: "inventory.balances.view", store: store)
    end

    def sales_visible?
      Authorization.allowed?(user: user, permission_key: "pos.transactions.view", store: store)
    end

    def receiving_visible?
      Authorization.allowed?(user: user, permission_key: "orders.receipts.view", store: store)
    end

    def snapshot
      @snapshot ||= VariantOperationalSnapshot.for_variants(store:, variants:, user:, item:)
    end

    private

    attr_reader :item, :store, :user

    def variants
      @variants ||= item.variants.to_a
    end

    def variant_ids
      @variant_ids ||= variants.map(&:id)
    end

    def warnings_by_variant
      @warnings_by_variant ||= warnings.group_by(&:variant_id)
    end

    def order_eligibility
      @order_eligibility ||= Purchasing::OrderEligibilityResolver.for_variants(
        store: store,
        variants: variants,
        context: :item_page,
        vendors_by_variant_id: snapshot.suggested_vendors.transform_values { |result| result.vendor },
        sourcing_by_variant_id: snapshot.sourcing_by_variant_id,
        suggested_vendors_by_variant_id: snapshot.suggested_vendors
      )
    end

    def last_sold_at
      @last_sold_at ||= sales_visible? ? SalesHistoryLookup.last_sold_at_for_variants(store:, variant_ids: variant_ids) : {}
    end

    def sell_card
      if variants.empty?
        return SummaryCard.new(
          key: :sell,
          label: "Can sell?",
          status: "Not set up",
          detail: "No active sellable SKUs",
          severity: :warning
        )
      end

      sell_warnings = warnings.select { |warning| warning.category == :selling }
      status = if sell_warnings.any? { |w| w.severity == :blocking }
        "Needs attention"
      elsif sell_warnings.any?
        "Review"
      else
        "Ready"
      end
      SummaryCard.new(
        key: :sell,
        label: "Can sell?",
        status: status,
        detail: "#{variants.count(&:active?)} active SKU(s)",
        severity: OperationalWarningBuilder.worst_severity(sell_warnings)
      )
    end

    def order_card
      if variants.empty?
        return SummaryCard.new(
          key: :order,
          label: "Can order?",
          status: "Not set up",
          detail: "No active sellable SKUs",
          severity: :warning
        )
      end

      order_warnings = warnings.select { |warning| warning.category == :ordering }
      eligible_count = order_eligibility.values.count(&:eligible)
      SummaryCard.new(
        key: :order,
        label: "Can order?",
        status: eligible_count == variants.size ? "Ready" : "Review",
        detail: "#{eligible_count}/#{variants.size} variant(s) orderable",
        severity: OperationalWarningBuilder.worst_severity(order_warnings)
      )
    end

    def stock_card
      rows = snapshot.rows.values
      available_total = rows.sum { |row| row.available || 0 }
      on_hand_total = rows.sum { |row| row.on_hand || 0 }
      on_order_total = rows.sum { |row| row.on_order || 0 }
      tbo_total = rows.sum(&:open_tbo)
      status = if available_total.positive?
        "Available"
      elsif on_hand_total.positive?
        "On hand"
      elsif on_order_total.positive?
        "On order"
      elsif tbo_total.positive?
        "TBO"
      else
        "No stock"
      end

      SummaryCard.new(
        key: :stock,
        label: "Stock",
        status: status,
        detail: "Avail. #{available_total} · TBO #{tbo_total} · On order #{on_order_total}",
        severity: nil
      )
    end

    def activity_card
      last_received = snapshot.rows.values.filter_map(&:last_received).max_by(&:received_at)
      last_sold = last_sold_at.values.compact.max
      detail_parts = []
      detail_parts << "Last received #{I18n.l(last_received.received_at.to_date)}" if last_received.present?
      detail_parts << "Last sold #{I18n.l(last_sold.to_date)}" if last_sold.present?
      if sales_visible? && variant_ids.any?
        rollup = SalesHistoryLookup.rollup_for_variants(store:, variant_ids:, days: [ 30 ]).values
        units_30d = rollup.sum { |by_day| by_day[30]&.units_sold.to_i }
        detail_parts << "#{units_30d} sold (30d)" if units_30d.positive?
      end
      SummaryCard.new(
        key: :activity,
        label: "Recent activity",
        status: detail_parts.any? ? "Updated" : "No history",
        detail: detail_parts.presence&.join(" · ") || "No recent sales or receipts",
        severity: nil
      )
    end

    def vendor_source_status(_variant, suggested, row_snapshot)
      return :missing if suggested.blank? || suggested.vendor.blank?
      return :warning unless row_snapshot&.sourcing_record_present

      :present
    end

    def open_po_line_count
      return 0 if variant_ids.empty?

      PurchaseOrderLine
        .joins(:purchase_order)
        .where(
          product_variant_id: variant_ids,
          purchase_orders: { store_id: store.id, status: Purchasing::OrderQuantityLookup::ACTIVE_PO_STATUSES },
          status: Purchasing::OrderQuantityLookup::OPEN_LINE_STATUSES
        )
        .count
    end

    def classification_for(variant)
      @classification_by_variant_id ||= {}
      @classification_by_variant_id[variant.id] ||= ClassificationDefaultsResolver.for(variant:, store:)
    end
  end
end
