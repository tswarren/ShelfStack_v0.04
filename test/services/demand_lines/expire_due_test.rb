# frozen_string_literal: true

require "test_helper"

class DemandLinesExpireDueTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include Phase4TestHelper
  include Phase5TestHelper
  include V0047TestHelper

  setup do
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    User.find_or_create_by!(username: ShelfStack::SYSTEM_USERNAME) do |user|
      user.user_type = "system"
      user.first_name = "System"
      user.last_name = "User"
      user.display_name = "System"
      user.interactive_login_enabled = false
      user.active = true
      user.password = "Password123!"
    end
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 2)
  end

  test "expires due demand lines and active allocations" do
    result = DemandLines::StartFromItem.call!(
      store: @store,
      variant: @variant,
      actor: @user,
      capture_intent: "hold",
      customer: create_customer!(display_name: "Due Customer"),
      quantity: 1,
      expires_at: 1.hour.ago
    )
    demand_line = result.demand_line
    assert demand_line.demand_allocations.active_allocations.exists?

    expire_result = travel_to Time.current do
      DemandLines::ExpireDue.call!(store: @store, actor: nil)
    end

    assert_equal 1, expire_result.expired_demand_count
    assert_equal 1, expire_result.expired_allocation_count
    assert_equal "expired", demand_line.reload.status
    assert demand_line.demand_allocations.where(status: "expired").exists?
    assert AuditEvent.exists?(event_name: "demand_line.expired_due", auditable: demand_line)
  end
end
