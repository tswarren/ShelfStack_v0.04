# frozen_string_literal: true

require "test_helper"

class SourcingRunsControllerTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase5TestHelper
  include V0047TestHelper
  include V0048TestHelper

  setup do
    seed_v0048_permissions!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_v0048_sourcing_permissions!(@user, store: @store)
    grant_v0047_allocation_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @vendor = create_vendor_for_variant!(@variant)
    @demand = create_special_order_demand!(store: @store, actor: @user, variant: @variant, quantity: 2)
  end

  test "index requires sourcing access" do
    get sourcing_root_path

    assert_response :success
    assert_includes response.body, "Sourcing"
  end

  test "start run from demand show panel" do
    post sourcing_runs_path, params: { demand_line_id: @demand.id, quantity: 2 }

    run = SourcingRun.last
    assert_redirected_to sourcing_run_path(run)
    assert_equal "open", run.status
  end

  test "create submit and record response workflow" do
    run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 2)

    post sourcing_run_attempts_path(run), params: { vendor_id: @vendor.id, quantity: 2 }
    attempt = run.sourcing_attempts.last
    assert_redirected_to sourcing_run_path(run)

    patch submit_sourcing_attempt_path(attempt)
    assert_equal "submitted", attempt.reload.status

    post sourcing_attempt_vendor_responses_path(attempt), params: {
      quantity_confirmed: 1,
      quantity_unavailable: 1,
      final_response: true
    }

    assert_redirected_to sourcing_run_path(run)
    assert_equal "partially_confirmed", attempt.reload.status
    assert_equal "needs_review", run.reload.status
  end

  test "cascade creates pending attempt" do
    run = Sourcing::StartRun.call!(demand_line: @demand, actor: @user, quantity: 2)
    attempt = Sourcing::CreateAttempt.call!(sourcing_run: run, actor: @user, vendor: @vendor, quantity: 2)
    Sourcing::SubmitAttempt.call!(sourcing_attempt: attempt, actor: @user)
    Sourcing::RecordVendorResponse.call!(
      sourcing_attempt: attempt.reload,
      actor: @user,
      quantity_unavailable: 2,
      final_response: true
    )

    alt = create_vendor!(name: "Cascade Vendor")
    post cascade_sourcing_attempt_path(attempt.reload), params: {
      vendor_id: alt.id,
      quantity: 2,
      cascade_reason: "unavailable"
    }

    cascaded = run.sourcing_attempts.order(:sequence_number).last
    assert_equal "pending", cascaded.status
    assert_redirected_to sourcing_run_path(run)
  end

  test "demand show includes sourcing panel" do
    get demand_demand_line_path(@demand)

    assert_response :success
    assert_includes response.body, "Unresolved for sourcing"
    assert_includes response.body, "Start sourcing run"
  end
end
