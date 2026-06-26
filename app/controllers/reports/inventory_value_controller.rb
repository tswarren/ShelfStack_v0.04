# frozen_string_literal: true

module Reports
  class InventoryValueController < BaseController
    before_action -> { authorize_report!("inventory.balances.view") }

    def show
      include_enterprise = Authorization.allowed?(
        user: current_user,
        permission_key: "inventory.enterprise.view",
        store: current_store
      )
      @report = InventoryValue::Query.call(store: report_store, include_enterprise: include_enterprise)
    end
  end
end
