# frozen_string_literal: true

require "test_helper"
require "rake"

class InventoryRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @admin = create_user!(username: "rakeadmin")
    role = Role.create!(role_key: "rake_inventory_admin", name: "Rake Inventory Admin", active: true)
    permission = Permission.find_by!(permission_key: "inventory.admin.rebuild_balances")
    role.grant_permission!(permission)
    UserRoleAssignment.create!(user: @admin, role: role, scope_type: "global", active: true)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    Current.store = @store
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 3, line_number: 1 } ]
      ),
      user: @admin
    )
  end

  test "rebuild_balances requires authorized username" do
  assert_raises(Inventory::AdminTaskAuthorization::AuthorizationError) do
      Inventory::AdminTaskAuthorization.authorize!(username: nil)
    end
  end

  test "rebuild_balances task runs with authorized user" do
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_column(:quantity_on_hand, 50)

    ENV["USERNAME"] = @admin.username
    capture_io do
      Rake::Task["shelfstack:inventory:rebuild_balances"].reenable
      Rake::Task["shelfstack:inventory:rebuild_balances"].invoke
    end

    assert_equal 3, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
  ensure
    ENV.delete("USERNAME")
  end

  test "check_integrity task exits non-zero on mismatch" do
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_column(:quantity_on_hand, 50)

    exit_code = nil
    capture_io do
      begin
        Rake::Task["shelfstack:inventory:check_integrity"].reenable
        Rake::Task["shelfstack:inventory:check_integrity"].invoke
      rescue SystemExit => e
        exit_code = e.status
      end
    end

    assert_equal 1, exit_code
  end

  test "expire_reservations task expires overdue holds" do
    Seeds::Phase7aPermissions.seed!
    User.find_or_create_by!(username: ShelfStack::SYSTEM_USERNAME) do |user|
      user.assign_attributes(
        user_type: "system",
        first_name: "ShelfStack",
        last_name: "System",
        display_name: "ShelfStack System",
        interactive_login_enabled: false,
        active: true,
        password: SecureRandom.hex(32)
      )
    end
    reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @admin,
      expires_at: 1.day.ago
    )

    capture_io do
      Rake::Task["shelfstack:inventory:expire_reservations"].reenable
      Rake::Task["shelfstack:inventory:expire_reservations"].invoke
    end

    assert_equal "expired", reservation.reload.status
  end

  private

  def capture_io
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end
