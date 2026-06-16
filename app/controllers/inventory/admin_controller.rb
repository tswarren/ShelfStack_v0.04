# frozen_string_literal: true

module Inventory
  class AdminController < BaseController
    before_action -> { authorize_admin! }

    def show
      @integrity_result = session[:inventory_integrity_result]
      session.delete(:inventory_integrity_result)
    end

    def rebuild_balances
      count = Inventory::RebuildBalances.call(actor: current_user)
      redirect_to inventory_admin_path, notice: "Rebuilt #{count} inventory balance(s)."
    end

    def integrity_check
      result = Inventory::BalanceIntegrityCheck.call(actor: current_user)
      session[:inventory_integrity_result] = {
        "passed" => result.passed,
        "mismatch_count" => result.mismatches.size,
        "mismatches" => result.mismatches.first(20).map do |m|
          {
            "store_id" => m.store_id,
            "product_variant_id" => m.product_variant_id,
            "cached_on_hand" => m.cached_on_hand,
            "ledger_on_hand" => m.ledger_on_hand
          }
        end
      }
      redirect_to inventory_admin_path
    end

    private

    def authorize_admin!
      return if Authorization.allowed?(
        user: current_user,
        permission_key: "inventory.admin.rebuild_balances",
        store: current_store
      )

      redirect_to inventory_root_path, alert: "You do not have inventory admin access."
    end
  end
end
