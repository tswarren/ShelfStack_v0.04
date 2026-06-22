# frozen_string_literal: true

require "test_helper"

class PurchasingReceiptLineDemandTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    @vendor = Vendor.first || Vendor.create!(name: "Vendor", active: true)
    @variant = create_product_variant!
    @po_line = PurchaseOrderLine.new(
      line_number: 1,
      product_variant: @variant,
      vendor: @vendor,
      quantity_ordered: 2,
      quantity_received: 0,
      unit_cost_cents: 500,
      variant_sku_snapshot: @variant.sku,
      variant_name_snapshot: @variant.name
    )
    @purchase_order = PurchaseOrder.create!(store: @store, vendor: @vendor, status: "submitted", purchase_order_lines: [ @po_line ])
    PurchaseOrderLineAllocation.create!(
      purchase_order_line: @po_line,
      special_order: create_special_order_with_allocation!,
      quantity_allocated: 2,
      quantity_received: 0,
      status: "active"
    )
  end

  test "customer_reserved_open sums open allocation quantity" do
    assert_equal 2, Purchasing::ReceiptLineDemand.customer_reserved_open(@po_line)
  end

  private

  def create_special_order_with_allocation!
    customer = create_customer!
    request = create_customer_request!(
      store: @store,
      created_by_user: @user,
      customer: customer,
      lines: [ { request_type: "special_order" } ]
    )
    line = request.customer_request_lines.first
    match_request_line!(line: line, variant: @variant, actor: @user)
    special_order = SpecialOrders::CreateFromRequestLine.call!(line: line, created_by_user: @user)
    SpecialOrders::Approve.call!(special_order: special_order, approved_by_user: @user)
    special_order
  end
end
