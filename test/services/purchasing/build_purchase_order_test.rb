# frozen_string_literal: true

require "test_helper"

class Purchasing::BuildPurchaseOrderTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "builds draft PO from manual lines" do
    order = Purchasing::BuildPurchaseOrder.call(
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

    assert_equal "draft", order.status
    assert_equal 1, order.purchase_order_lines.size
    assert_equal 3, order.purchase_order_lines.first.quantity_ordered
    assert AuditEvent.exists?(event_name: "purchase_order.created", auditable: order)
  end

  test "requires at least one line" do
    assert_raises Purchasing::BuildPurchaseOrder::BuildError do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user
      )
    end
  end

  test "blocks ineligible variant at po build" do
    @variant.update!(orderable: false)

    assert_raises(Purchasing::BuildPurchaseOrder::BuildError) do
      Purchasing::BuildPurchaseOrder.call(
        store: @store,
        vendor: @vendor,
        created_by_user: @user,
        manual_lines: [
          {
            product_variant_id: @variant.id,
            quantity_ordered: 1,
            line_number: 1
          }
        ]
      )
    end
  end
end
