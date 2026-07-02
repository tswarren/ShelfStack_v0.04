# frozen_string_literal: true

require "test_helper"

class Items::ItemDocumentTrailBuilderTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @user = create_user!
    @variant = create_product_variant!
    @item = Items::ItemPresenter.from_product(@variant.product)
    @purchase_order = PurchaseOrder.create!(
      store: @store,
      vendor: @vendor,
      status: "draft",
      purchase_order_lines: [
        PurchaseOrderLine.new(
          line_number: 1,
          product_variant: @variant,
          vendor: @vendor,
          quantity_ordered: 2,
          quantity_received: 0,
          status: "open"
        )
      ]
    )
  end

  test "builds trail nodes for item variants" do
    nodes = Items::ItemDocumentTrailBuilder.for(item: @item, store: @store)

    assert nodes.any? { |node| node.label.start_with?("PO #") }
    assert nodes.all?(&:occurred_at)
  end
end
