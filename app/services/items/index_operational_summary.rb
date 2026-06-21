# frozen_string_literal: true

module Items
  class IndexOperationalSummary
    Summary = Data.define(:available, :open_tbo, :on_order, :last_received_at, :actions)

    Action = Data.define(:label, :url, :permission_key)

    def self.for(store:, user:, results:, match_context: nil)
      new(store: store, user: user, results: results, match_context: match_context).summaries_by_presenter
    end

    def initialize(store:, user:, results:, match_context: nil)
      @store = store
      @user = user
      @results = Array(results)
      @match_context = match_context
    end

    def summaries_by_presenter
      results.each_with_object({}) do |result, summaries|
        presenter = result.presenter
        summaries[presenter] = summary_for(presenter)
      end
    end

    private

    attr_reader :store, :user, :results

    def summary_for(presenter)
      operations = ItemOperationsPresenter.new(item: presenter, store: store, user: user)
      rows = operations.variant_rows
      last_received = rows.filter_map(&:last_received).max_by(&:received_at)

      Summary.new(
        available: rows.sum { |row| row.available || 0 },
        open_tbo: rows.sum(&:open_tbo),
        on_order: rows.sum { |row| row.on_order || 0 },
        last_received_at: last_received&.received_at,
        actions: index_actions(presenter, operations)
      )
    end

    def index_actions(presenter, operations)
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
      if allowed?("orders.purchase_orders.create")
        actions << Action.new(
          label: "Order",
          url: Rails.application.routes.url_helpers.from_tbo_orders_purchase_orders_path,
          permission_key: "orders.purchase_orders.create"
        )
      end
      receivable_po = operations.receivable_purchase_order_for_item
      if receivable_po && allowed?("orders.receipts.create")
        actions << Action.new(
          label: "Receive",
          url: Rails.application.routes.url_helpers.receive_orders_purchase_order_path(receivable_po),
          permission_key: "orders.receipts.create"
        )
      end

      actions.select { |action| action.permission_key.blank? || allowed?(action.permission_key) }
    end

    def allowed?(permission_key)
      Authorization.allowed?(user: user, permission_key: permission_key, store: store)
    end
  end
end
