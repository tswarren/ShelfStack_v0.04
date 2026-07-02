# frozen_string_literal: true

require "test_helper"

class SourcingCascadeTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0048TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant)
    @alt_vendor = create_vendor!(name: "Alt Vendor")
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 3)
    @run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 3)
    @attempt = Sourcing::CreateAttempt.call!(sourcing_run: @run, actor: @user, vendor: @vendor, quantity: 3)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: @attempt, actor: @user)
    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: @attempt.reload,
      actor: @user,
      quantity_confirmed: 1,
      quantity_unavailable: 2,
      final_response: true
    )
  end

  test "cascade creates pending attempt and marks predecessor cascaded" do
    cascaded = Sourcing::Cascade.call!(
      previous_attempt: @attempt.reload,
      actor: @user,
      vendor: @alt_vendor,
      quantity: 2,
      cascade_reason: "unavailable"
    )

    assert_equal "pending", cascaded.status
    assert_equal "cascaded", @attempt.reload.status
    assert_equal @attempt.id, cascaded.previous_sourcing_attempt_id
    assert AuditEvent.exists?(event_name: "sourcing_attempt.cascaded", auditable: cascaded)
  end
end
