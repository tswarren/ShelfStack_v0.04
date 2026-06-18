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
    @request = PurchaseRequest.create!(store: @store, status: "open")
    @request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
  end

  test "builds trail nodes for item variants" do
    nodes = Items::ItemDocumentTrailBuilder.for(item: @item, store: @store)

    assert nodes.any? { |node| node.label.start_with?("TBO #") }
    assert nodes.all?(&:occurred_at)
  end
end
