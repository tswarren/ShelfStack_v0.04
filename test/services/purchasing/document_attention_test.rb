# frozen_string_literal: true

require "test_helper"

class Purchasing::DocumentAttentionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4, quantity_received: 1) ]
    )
    @purchase_order.update!(status: "partially_received")
    @hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)
  end

  test "flags open lines on partially received purchase orders" do
    items = Purchasing::DocumentAttention.for_purchase_order(
      purchase_order: @purchase_order,
      document_hub: @hub,
      sourcing_warnings: []
    )

    assert items.any? { |item| item.message.include?("still open to receive") }
  end
end
