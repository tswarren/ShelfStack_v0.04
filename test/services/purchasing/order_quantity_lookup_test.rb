# frozen_string_literal: true

require "test_helper"

class Purchasing::OrderQuantityLookupTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "submitted purchase order counts full quantity as on order" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 8)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 8, result.on_order
    assert_equal 0, result.pending
  end

  test "draft purchase order counts as pending not on order" do
    create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5)]
    )

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 0, result.on_order
    assert_equal 5, result.pending
  end

  test "partial receive reduces on order remainder" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 10)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first
    po_line.update_columns(quantity_received: 4, status: "partially_received")
    order.update_column(:status, "partially_received")

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 6, result.on_order
    assert_equal 0, result.pending
  end

  test "fully received line is excluded from on order" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 6)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    po_line = order.purchase_order_lines.first
    po_line.update_columns(quantity_received: 6, status: "received")
    order.update_column(:status, "received")

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 0, result.on_order
    assert_equal 0, result.pending
  end

  test "cancelled purchase order is excluded" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    order.update!(status: "cancelled")

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 0, result.on_order
    assert_equal 0, result.pending
  end

  test "cancelled line is excluded" do
    order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order, submitted_by_user: @user)
    order.purchase_order_lines.first.update_column(:status, "cancelled")

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 0, result.on_order
  end

  test "sums multiple purchase orders for the same variant" do
    order_one = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 2)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order_one, submitted_by_user: @user)

    order_two = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 3)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: order_two, submitted_by_user: @user)

    result = Purchasing::OrderQuantityLookup.for_variant(store: @store, variant: @variant)

    assert_equal 5, result.on_order
  end

  test "for_variants returns batch results matching single lookups" do
    other_variant = create_product_variant!(sub_department: @variant.sub_department, inventory_behavior: "standard_physical")

    submitted_order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 4)]
    )
    Purchasing::SubmitPurchaseOrder.call(purchase_order: submitted_order, submitted_by_user: @user)

    create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [create_purchase_order_line_attrs(variant: other_variant, vendor: @vendor, quantity_ordered: 7)]
    )

    batch = Purchasing::OrderQuantityLookup.for_variants(
      store: @store,
      variant_ids: [ @variant.id, other_variant.id ]
    )

    assert_equal 4, batch[@variant.id].on_order
    assert_equal 0, batch[@variant.id].pending
    assert_equal 0, batch[other_variant.id].on_order
    assert_equal 7, batch[other_variant.id].pending
  end
end
