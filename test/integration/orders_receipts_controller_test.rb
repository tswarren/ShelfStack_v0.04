# frozen_string_literal: true

require "test_helper"

class OrdersReceiptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase5_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)

    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @receipt = Receipt.create!(store: @store, vendor: @vendor, receipt_type: "direct", status: "draft")
    @line = @receipt.receipt_lines.create!(
      product_variant: @variant,
      quantity_expected: 0,
      quantity_received: 5,
      quantity_accepted: 5,
      quantity_rejected: 0
    )
  end

  test "update lowers accepted when received decreases" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 3,
            quantity_accepted: 5,
            quantity_rejected: 0
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    assert_equal 3, @line.reload.quantity_accepted
    assert_equal 3, @line.quantity_received
  end

  test "update ignores blank added line rows" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 8,
            quantity_accepted: 0,
            quantity_rejected: 0
          },
          "1" => {
            product_variant_id: "",
            quantity_expected: 0,
            quantity_received: 0,
            quantity_accepted: 0,
            quantity_rejected: 0
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    assert_equal 8, @line.reload.quantity_received
    assert_equal 1, @receipt.receipt_lines.count
  end

  test "update applies exception quantity and reason" do
    patch orders_receipt_path(@receipt), params: {
      receipt: {
        vendor_id: @vendor.id,
        receipt_type: "direct",
        receipt_lines_attributes: {
          "0" => {
            id: @line.id,
            product_variant_id: @variant.id,
            quantity_expected: 0,
            quantity_received: 10,
            quantity_accepted: 0,
            quantity_rejected: 2,
            exception_reason: "damaged"
          }
        }
      }
    }

    assert_redirected_to orders_receipt_path(@receipt)
    @line.reload
    assert_equal 8, @line.quantity_accepted
    assert_equal 2, @line.quantity_rejected
    assert_equal "damaged", @line.exception_reason
  end
end
