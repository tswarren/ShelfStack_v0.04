# frozen_string_literal: true

require "test_helper"

class Purchasing::SubmitPurchaseOrderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 2500)
    @variant.product.update!(list_price_cents: 2000)
    ProductVendor.create!(
      product: @variant.product,
      vendor: @vendor,
      vendor_item_number: "VEND-123",
      supplier_discount_bps: 4000,
      returnability_status: "returnable",
      active: true
    )
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 5) ]
    )
  end

  test "snapshots line pricing and metadata at submit" do
    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)

    line = @order.purchase_order_lines.first.reload
    assert_equal "submitted", @order.status
    assert_equal @variant.sku, line.variant_sku_snapshot
    assert_equal @variant.name, line.variant_name_snapshot
    assert_equal "VEND-123", line.vendor_item_number_snapshot
    assert_equal 2000, line.unit_list_price_cents
    assert_equal 4000, line.supplier_discount_bps
    assert_equal 1200, line.unit_cost_cents
    assert_equal 2500, line.expected_retail_price_cents
    assert_equal "vendor_source", line.cost_source
    assert_equal "returnable", line.returnability_status_snapshot
    assert AuditEvent.exists?(event_name: "purchase_order.submitted", auditable: @order)
  end

  test "blocks submit when line is not orderable" do
    @variant.update!(orderable: false)

    assert_raises(Purchasing::SubmitPurchaseOrder::SubmitError) do
      Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    end
  end

  test "rejects submit when not draft" do
    @order.update!(status: "submitted", submitted_at: Time.current, submitted_by_user: @user)

    assert_raises(Purchasing::SubmitPurchaseOrder::SubmitError) do
      Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)
    end
  end

  test "fills missing economics from defaults before submit snapshot" do
    line = @order.purchase_order_lines.first
    line.update_columns(
      unit_list_price_cents: nil,
      supplier_discount_bps: nil,
      unit_cost_cents: nil,
      expected_line_cost_cents: nil,
      expected_margin_cents: nil
    )

    Purchasing::SubmitPurchaseOrder.call(purchase_order: @order, submitted_by_user: @user)

    line.reload
    assert_equal 2000, line.unit_list_price_cents
    assert_equal 4000, line.supplier_discount_bps
    assert_equal 1200, line.unit_cost_cents
    assert_equal 6000, line.expected_line_cost_cents
  end

  test "blocks submit when unit cost cannot be determined" do
    service = Purchasing::SubmitPurchaseOrder.new(purchase_order: @order, submitted_by_user: @user)
    service.define_singleton_method(:prepare_line_economics!) do |line|
      line.unit_cost_cents = nil
    end

    error = assert_raises(Purchasing::SubmitPurchaseOrder::SubmitError) do
      service.call
    end

    assert_match(/Expected unit cost could not be determined/, error.message)
  end
end
