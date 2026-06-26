# frozen_string_literal: true

module Items
  class IndexOperationalSummary
    Summary = Data.define(:available, :open_tbo, :on_order, :last_received_at, :actions, :warning_summary)

    Action = Data.define(:label, :url, :permission_key)

    def self.for(store:, user:, results:, match_context: nil, warning_summaries: nil)
      new(store: store, user: user, results: results, match_context: match_context, warning_summaries: warning_summaries).summaries_by_presenter
    end

    def initialize(store:, user:, results:, match_context: nil, warning_summaries: nil)
      @store = store
      @user = user
      @results = Array(results)
      @match_context = match_context
      @warning_summaries = warning_summaries || {}
    end

    def summaries_by_presenter
      return {} if results.empty?

      snapshots_by_item = batch_snapshots
      results.each_with_object({}) do |result, summaries|
        presenter = result.presenter
        summaries[presenter] = summary_for(presenter, snapshots_by_item.fetch(presenter, {}))
      end
    end

    private

    attr_reader :store, :user, :results, :match_context, :warning_summaries

    def batch_snapshots
      all_variants = results.flat_map { |result| result.presenter.variants.to_a }.uniq
      shared_snapshot = VariantOperationalSnapshot.for_variants(store:, variants: all_variants, user:)

      results.each_with_object({}) do |result, hash|
        presenter = result.presenter
        variant_ids = presenter.variants.map(&:id)
        hash[presenter] = shared_snapshot.rows.slice(*variant_ids)
      end
    end

    def summary_for(presenter, row_slice)
      rows = row_slice.values
      last_received = rows.filter_map(&:last_received).max_by(&:received_at)

      Summary.new(
        available: rows.sum { |row| row.available || 0 },
        open_tbo: rows.sum(&:open_tbo),
        on_order: rows.sum { |row| row.on_order || 0 },
        last_received_at: last_received&.received_at,
        actions: index_actions(presenter, rows),
        warning_summary: warning_summaries[presenter]
      )
    end

    def index_actions(presenter, rows)
      actions = [
        Action.new(label: "View", url: presenter.show_path, permission_key: nil)
      ]

      eligible_variant = presenter.variants.find { |variant| Inventory::Eligibility.eligible?(variant) }
      if eligible_variant && allowed?("orders.purchase_requests.create")
        actions << Action.new(
          label: "TBO",
          url: Rails.application.routes.url_helpers.new_orders_purchase_request_path(product_variant_id: eligible_variant.id),
          permission_key: "orders.purchase_requests.create"
        )
      end
      if eligible_variant && allowed?("orders.purchase_orders.create")
        actions << Action.new(
          label: "Order",
          url: Rails.application.routes.url_helpers.from_tbo_orders_purchase_orders_path,
          permission_key: "orders.purchase_orders.create"
        )
      end

      receivable_po = receivable_purchase_order_for(presenter)
      if receivable_po && allowed?("orders.receipts.create")
        actions << Action.new(
          label: "Receive",
          url: Rails.application.routes.url_helpers.receive_orders_purchase_order_path(receivable_po),
          permission_key: "orders.receipts.create"
        )
      end

      actions.select { |action| action.permission_key.blank? || allowed?(action.permission_key) }
    end

    def receivable_purchase_order_for(presenter)
      variant_ids = presenter.variants.map(&:id)
      return nil if variant_ids.empty?

      PurchaseOrder
        .joins(:purchase_order_lines)
        .where(store: store, status: %w[submitted partially_received])
        .where(purchase_order_lines: {
          product_variant_id: variant_ids,
          status: Purchasing::OrderQuantityLookup::OPEN_LINE_STATUSES
        })
        .distinct
        .order(:id)
        .first
    end

    def allowed?(permission_key)
      Authorization.allowed?(user: user, permission_key: permission_key, store: store)
    end
  end
end
