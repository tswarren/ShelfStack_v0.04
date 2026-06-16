# frozen_string_literal: true

module Phase4TestHelper
  def seed_phase4_reference_data!
    Seeds::Phase4Inventory.seed!
  end

  def grant_all_phase4_permissions!(user, store: nil)
    Seeds::Phase4Permissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def create_inventory_adjustment!(store:, attrs: {}, lines: [])
    adjustment = InventoryAdjustment.create!({
      store: store,
      adjustment_type: "manual_adjustment",
      status: "draft"
    }.merge(attrs))

    lines.each do |line_attrs|
      adjustment.inventory_adjustment_lines.create!(line_attrs)
    end

    adjustment
  end

  def post_inventory_adjustment!(adjustment, user:)
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: user)
  end
end
