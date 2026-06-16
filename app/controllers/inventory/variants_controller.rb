# frozen_string_literal: true

module Inventory
  class VariantsController < BaseController
    before_action -> { authorize!("inventory.ledger.view") }
    before_action :set_variant

    def show
      @balance = InventoryBalance.find_by(store: inventory_store, product_variant: @variant)
      @ledger_entries = InventoryLedgerEntry
        .includes(:inventory_posting, :inventory_reason_code)
        .where(store: inventory_store, product_variant: @variant)
        .order(occurred_at: :desc, id: :desc)
        .limit(100)
    end

    private

    def set_variant
      @variant = ProductVariant.find(params[:id])
    end
  end
end
