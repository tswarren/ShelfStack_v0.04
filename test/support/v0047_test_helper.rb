# frozen_string_literal: true

module V0047TestHelper
  def seed_v0047_permissions!
    Seeds::V0046Permissions.seed!
    Seeds::V0047Permissions.seed!
  end

  def grant_v0047_allocation_permissions!(user, store: nil)
    %w[
      demand.access
      demand.create
      demand.cancel
      demand.expire
      demand.allocations.create
      demand.allocations.release
      demand.allocations.cancel
      demand.allocations.expire
      demand.allocations.fulfill
      demand.allocations.override_availability
      demand.expire_due
    ].each do |key|
      grant_permission!(user, key, store: store)
    end
  end

  def inventory_snapshot(store:, variant:)
    balance = InventoryBalance.find_by(store: store, product_variant: variant)
    {
      ledger_count: InventoryLedgerEntry.where(store: store, product_variant: variant).count,
      on_hand: balance&.quantity_on_hand.to_i,
      reserved: balance&.quantity_reserved.to_i,
      available: balance&.quantity_available.to_i
    }
  end

  def assert_inventory_unchanged_except_cache(before:, after:)
    assert_equal before[:ledger_count], after[:ledger_count], "ledger count changed"
    assert_equal before[:on_hand], after[:on_hand], "on_hand changed"
  end

  def create_open_demand_line!(store:, actor:, variant:, capture_intent: "notify", **attrs)
    customer = attrs.delete(:customer) || create_customer!(display_name: "Demand Customer")
    DemandLines::Create.call!(
      store: store,
      actor: actor,
      capture_intent: capture_intent,
      variant: variant,
      customer: customer,
      **attrs
    )
  end
end
