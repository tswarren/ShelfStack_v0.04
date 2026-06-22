# frozen_string_literal: true

require "test_helper"

class PosHelperPickupSummaryTest < ActionView::TestCase
  include PosHelper
  include Phase2TestHelper
  include Phase6TestHelper
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    post_inventory_adjustment!(
      create_inventory_adjustment!(
        store: @store,
        lines: [ { product_variant: @variant, quantity_delta: 2, line_number: 1 } ]
      ),
      user: @user
    )
    @customer = create_customer!(display_name: "Banner Pat")
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
    @transaction = PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: "draft"
    )
    @transaction.pos_transaction_lines.create!(
      line_number: 1,
      line_type: "variant",
      product_variant: @variant,
      product: @variant.product,
      quantity: 1,
      unit_price_cents: @variant.selling_price_cents,
      line_discount_cents: 0,
      extended_price_cents: 0,
      tax_cents: 0,
      inventory_reservation: @reservation,
      customer_request_line: @line
    )
  end

  test "pos_transaction_pickup_summary returns customer and request" do
    summary = pos_transaction_pickup_summary(@transaction)

    assert_equal "Banner Pat", summary.customer_name
    assert_includes summary.request_numbers, @customer_request.request_number
    assert_equal 1, summary.line_count
  end

  test "pos_line_pickup_context returns structured pickup data" do
    line = @transaction.pos_transaction_lines.first
    context = pos_line_pickup_context(line)

    assert_equal "Banner Pat", context.customer_name
    assert_equal @customer_request.request_number, context.request_number
  end
end
