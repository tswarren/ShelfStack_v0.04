# frozen_string_literal: true

require "test_helper"

class Purchasing::DocumentTrailBuilderTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!
    @purchase_order = Purchasing::BuildPurchaseOrder.call(
      store: @store,
      vendor: @vendor,
      created_by_user: @user,
      manual_lines: [
        {
          product_variant_id: @variant.id,
          quantity_ordered: 3,
          line_number: 1
        }
      ]
    )
    @po_hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)
  end

  test "builds purchase order trail through receipts" do
    nodes = Purchasing::DocumentTrailBuilder.for_purchase_order(@purchase_order, document_hub: @po_hub)

    assert_includes nodes.map(&:label), "PO ##{@purchase_order.id}"
  end
end
