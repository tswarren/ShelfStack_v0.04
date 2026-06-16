# frozen_string_literal: true

require "test_helper"

class SetupInventoryReasonCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "invsetup", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.inventory_reason_codes.view")
    grant_permission!(@admin, "setup.inventory_reason_codes.create")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "invsetup", password: "Password123!" }
  end

  test "create reason code records audit event" do
    post setup_inventory_reason_codes_path, params: {
      inventory_reason_code: {
        reason_key: "test_seed",
        name: "Test Seed Reason",
        sort_order: 99,
        active: true
      }
    }

    code = InventoryReasonCode.find_by!(reason_key: "test_seed")
    assert_redirected_to setup_inventory_reason_code_path(code)
    assert AuditEvent.exists?(event_name: "inventory_reason_code.created", auditable: code)
  end
end
