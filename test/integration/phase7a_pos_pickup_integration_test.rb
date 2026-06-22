# frozen_string_literal: true

require "test_helper"

class Phase7aPosPickupIntegrationTest < ActionDispatch::IntegrationTest
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase6Permissions.seed!
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(pin: "1234")
    grant_all_phase6_permissions!(@user, store: @store)
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!(display_name: "Pickup Pat")
    @customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: @customer,
      lines: [ { request_type: "hold" } ]
    )
    @line = @customer_request.customer_request_lines.first
    match_request_line!(line: @line, variant: @variant, actor: @user)
    @reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: @customer,
      customer_request_line: @line
    )
    @reservation.update!(status: "ready")
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
  end

  test "pickup lookup finds walk-in snapshot customer by name" do
    walk_in_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      lines: [ { request_type: "hold" } ]
    )
    walk_in_line = walk_in_request.customer_request_lines.first
    match_request_line!(line: walk_in_line, variant: @variant, actor: @user)
    walk_in_reservation = InventoryReservations::ReserveOnHand.call!(
      store: @store,
      variant: @variant,
      quantity: 1,
      reserved_by_user: @user,
      customer: nil,
      customer_request_line: walk_in_line
    )
    walk_in_reservation.update!(status: "ready")

    post pos_pickup_lookup_path, params: { query: walk_in_request.customer_name_snapshot }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    reservation_ids = body["pickups"].map { |row| row["reservation_id"] }
    assert_includes reservation_ids, walk_in_reservation.id
    assert_equal walk_in_request.customer_name_snapshot, body["pickups"].find { |row| row["reservation_id"] == walk_in_reservation.id }["customer_name"]
  end

  test "pickup lookup returns ready reservation" do
    post pos_pickup_lookup_path, params: { query: "Pickup Pat" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["pickups"].size
    assert_equal @reservation.id, body["pickups"].first["reservation_id"]
  end

  test "add_reservation_line adds pickup line to transaction" do
    post add_reservation_line_pos_transaction_path(@transaction),
         params: { inventory_reservation_id: @reservation.id },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    line = @transaction.reload.pos_transaction_lines.first
    assert_equal @reservation.id, line.inventory_reservation_id
    assert_equal @customer.id, @transaction.customer_id
  end

  test "pickup mode renders promoted pickup panel" do
    get edit_pos_transaction_path(@transaction, mode: "pickup")

    assert_response :success
    assert_includes response.body, "Find pickup"
    assert_includes response.body, "ss-pos-mode-switch"
  end

  test "add_reservation_line accepts quantity parameter" do
    @reservation.update!(quantity_reserved: 2)

    post add_reservation_line_pos_transaction_path(@transaction),
         params: { inventory_reservation_id: @reservation.id, quantity: 2 },
         headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    line = @transaction.reload.pos_transaction_lines.first
    assert_equal 2, line.quantity
  end
end
