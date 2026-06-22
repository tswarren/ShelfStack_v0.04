# frozen_string_literal: true

require "test_helper"

class InventoryReservationsExpireJobTest < ActiveJob::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
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
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 1, line_number: 1 } ]
      ),
      user: @user
    )
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "hold" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer_request_line: @line,
      expires_at: 1.day.ago
    )
  end

  test "perform expires overdue reservations" do
    InventoryReservations::ExpireJob.perform_now

    assert_equal "expired", @reservation.reload.status
  end
end
