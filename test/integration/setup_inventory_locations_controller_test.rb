# frozen_string_literal: true

require "test_helper"

class SetupInventoryLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase4_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "invloc", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_permission!(@admin, "setup.inventory_locations.view")
    grant_permission!(@admin, "setup.inventory_locations.create")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "invloc", password: "Password123!" }
  end

  test "create inventory location records audit event" do
    post setup_inventory_locations_path, params: {
      inventory_location: {
        store_id: @store.id,
        name: "Receiving",
        short_name: "RCV",
        sort_order: 30,
        active: true
      }
    }

    location = InventoryLocation.find_by!(short_name: "RCV", store: @store)
    assert_redirected_to setup_inventory_location_path(location)
    assert AuditEvent.exists?(event_name: "inventory_location.created", auditable: location)
  end
end
