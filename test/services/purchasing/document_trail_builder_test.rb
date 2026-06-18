# frozen_string_literal: true

require "test_helper"

class Purchasing::DocumentTrailBuilderTest < ActiveSupport::TestCase
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
    @purchase_order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      purchase_request_lines: [ @request_line ]
    )
    @po_hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)
  end

  test "builds purchase order trail from TBO through receipts" do
    nodes = Purchasing::DocumentTrailBuilder.for_purchase_order(@purchase_order, document_hub: @po_hub)

    assert_includes nodes.map(&:label), "TBO ##{@purchase_request.id}"
    assert_includes nodes.map(&:label), "PO ##{@purchase_order.id}"
  end

  test "builds purchase request trail through related purchase orders" do
    hub = Purchasing::PurchaseRequestDocumentHub.call(@purchase_request)
    nodes = Purchasing::DocumentTrailBuilder.for_purchase_request(@purchase_request, document_hub: hub)

    assert_equal "TBO ##{@purchase_request.id}", nodes.first.label
    assert_includes nodes.map(&:label), "PO ##{@purchase_order.id}"
  end
end
