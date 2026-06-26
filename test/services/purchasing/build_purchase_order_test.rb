# frozen_string_literal: true

require "test_helper"

class Purchasing::BuildPurchaseOrderTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "builds draft PO from purchase request lines and marks lines added_to_po" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 3,
      request_reason: "tbo",
      status: "open"
    )

    order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ request_line ]
    )

    assert_equal "draft", order.status
    assert_equal 1, order.purchase_order_lines.size
    assert_equal 3, order.purchase_order_lines.first.quantity_ordered
    assert_equal request_line.id, order.purchase_order_lines.first.purchase_request_line_id
    assert_equal "added_to_po", request_line.reload.status
    assert AuditEvent.exists?(event_name: "purchase_order.created", auditable: order)
  end

  test "requires at least one line" do
    assert_raises Purchasing::BuildPurchaseOrder::BuildError do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user
      )
    end
  end

  test "supports partial order quantity and marks line partially_ordered" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 10,
      request_reason: "tbo",
      status: "open"
    )

    order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ request_line ],
      line_quantities: { request_line.id => 4 }
    )

    assert_equal 4, order.purchase_order_lines.first.quantity_ordered
    assert_equal "partially_ordered", request_line.reload.status
    assert_equal "partially_ordered", request.reload.status
  end

  test "rejects order quantity above remaining tbo quantity" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 3,
      status: "open"
    )

    assert_raises Purchasing::BuildPurchaseOrder::BuildError do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user,
        purchase_request_lines: [ request_line ],
        line_quantities: { request_line.id => 5 }
      )
    end
  end

  test "cannot merge special order onto tbo-backed po line" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
    customer = create_customer!
    customer_request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "special_order" } ]
    )
    cr_line = customer_request.customer_request_lines.first
    match_request_line!(line: cr_line, variant: @variant, actor: @user)
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: cr_line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: @user)

    assert_raises(Purchasing::BuildPurchaseOrder::BuildError, match: /TBO-backed/) do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user,
        purchase_request_lines: [ request_line ],
        special_orders: [ special_order ]
      )
    end
  end

  test "blocks ineligible variant at po build" do
    @variant.update!(orderable: false)

    request = PurchaseRequest.create!(store: @store, status: "open")
    request_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 1,
      status: "open"
    )

    assert_raises(Purchasing::BuildPurchaseOrder::BuildError) do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user,
        purchase_request_lines: [ request_line ]
      )
    end
  end
end
