# frozen_string_literal: true

require "test_helper"

class Purchasing::PurchaseRequestDocumentHubTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!
    @purchase_request = PurchaseRequest.create!(store: @store, status: "open")
    @request_line = @purchase_request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 3,
      status: "open"
    )
  end

  test "summarizes lines and links purchase orders" do
    order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ @request_line ]
    )
    @purchase_request.refresh_status_from_lines!

    hub = Purchasing::PurchaseRequestDocumentHub.call(@purchase_request.reload)

    assert_equal 1, hub.summary.line_count
    assert_equal 0, hub.summary.buildable_line_count
    assert_equal 1, hub.summary.added_line_count
    assert_equal false, hub.buildable
    assert_equal 1, hub.purchase_orders.size
    assert_equal order.id, hub.purchase_orders.first.purchase_order.id
    assert_equal order.purchase_order_lines.first.id, hub.lines.first.purchase_order_line.id
  end
end
