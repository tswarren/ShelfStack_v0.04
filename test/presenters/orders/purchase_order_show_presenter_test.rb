# frozen_string_literal: true

require "test_helper"

class Orders::PurchaseOrderShowPresenterTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!
    @purchase_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5, quantity_received: 2) ]
    )
    @order_summary = Purchasing::PurchaseOrderSummary.call(@purchase_order)
    @document_hub = Purchasing::PurchaseOrderDocumentHub.call(@purchase_order)
    @presenter = Orders::PurchaseOrderShowPresenter.new(
      purchase_order: @purchase_order,
      document_hub: @document_hub,
      order_summary: @order_summary,
      sourcing_warnings: []
    )
  end

  test "exposes metric strip values from hub and summary" do
    metrics = @presenter.metrics

    assert_equal "Ordered", metrics[0][:label]
    assert_equal 5, metrics[0][:value]
    assert_equal "Total cost", metrics[3][:label]
  end

  test "flags lines without vendor sourcing" do
    line = @purchase_order.purchase_order_lines.first
    flags = @presenter.line_flags(line)

    assert_includes flags, "No source"
  end
end
