# frozen_string_literal: true

require "test_helper"

class InventoryReservationsReserveOnHandTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!
    receive_inventory!(store: @store, vendor: @vendor, variant: @variant, user: @user, quantity: 5)
  end

  test "hold reduces quantity_available" do
    reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 2,
      reserved_by_user: @user
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 5, balance.quantity_on_hand
    assert_equal 2, balance.quantity_reserved
    assert_equal 3, balance.quantity_available
    assert_equal "on_hand_hold", reservation.reservation_type
  end

  test "rejects over-reserve without override" do
    assert_raises(InventoryReservations::ReserveOnHand::ReserveError) do
      InventoryReservations::ReserveOnHand.call!(
        store: @store,
        variant: @variant,
        quantity: 10,
        reserved_by_user: @user
      )
    end
  end
end
