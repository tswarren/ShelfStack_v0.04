# frozen_string_literal: true

module Items
  class VariantOperationsDrawerPresenter
    include Rails.application.routes.url_helpers

    def self.for(item:, store:, user:, variant:)
      new(item:, store:, user:, variant:)
    end

    def initialize(item:, store:, user:, variant:)
      @item = item
      @store = store
      @user = user
      @variant = variant
    end

    attr_reader :item, :store, :user, :variant

    def variant_row
      @variant_row ||= operations_presenter.variant_rows.find { |row| row.variant.id == variant.id }
    end

    def operations_tab
      @operations_tab ||= ItemOperationsTabPresenter.new(
        item: item,
        store: store,
        user: user,
        highlight_variant: variant
      )
    end

    def warnings
      @warnings ||= OperationalWarningBuilder.for_variants(
        store: store,
        variants: [ variant ],
        contexts: OperationalWarningBuilder.default_contexts,
        item: item
      ).fetch(variant.id, [])
    end

    def recommended_actions
      operations_presenter.variant_drawer_actions(variant)
    end

    def demand_actions
      operations_presenter.variant_customer_demand_actions(variant)
    end

    def legacy_activity_present?
      tab = operations_tab
      return false unless customer_demand_visible?

      tab.variant_scoped_customer_request_lines.any? ||
        tab.variant_scoped_active_holds.any? ||
        tab.variant_scoped_incoming_reserves.any? ||
        tab.variant_scoped_special_orders.any? ||
        tab.variant_scoped_purchase_request_lines.any?
    end

    def availability_context
      operations_presenter.availability_context(variant)
    end

    def customer_demand_visible?
      operations_presenter.customer_demand_visible?
    end

    private

    def operations_presenter
      @operations_presenter ||= ItemOperationsPresenter.new(item: item, store: store, user: user)
    end
  end
end
