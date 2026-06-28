# frozen_string_literal: true

require "test_helper"

class PurchaseRequestTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase4_reference_data!
    @store = create_store!
    @vendor = create_vendor!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @user = create_user!
    Current.store = @store
  end

  test "creating purchase request does not change inventory" do
    balance_count_before = InventoryBalance.where(store: @store, product_variant: @variant).count
    posting_count_before = InventoryPosting.count

    request = PurchaseRequest.create!(store: @store, status: "open")
    request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 5,
      request_reason: "tbo",
      status: "open"
    )

    assert_equal balance_count_before, InventoryBalance.where(store: @store, product_variant: @variant).count
    assert_equal posting_count_before, InventoryPosting.count
  end

  test "buildable lines exclude added_to_po and cancelled" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    open_line = request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
    other_variant = create_product_variant!(sub_department: @variant.sub_department, inventory_behavior: "standard_physical")
    added_line = request.purchase_request_lines.create!(
      product_variant: other_variant,
      requested_quantity: 1,
      status: "added_to_po"
    )

    assert request.buildable?
    assert_includes request.buildable_lines, open_line
    assert_not_includes request.buildable_lines, added_line
  end

  test "refresh_status_from_lines updates header when all lines added_to_po" do
    request = PurchaseRequest.create!(store: @store, status: "open")
    request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 1,
      status: "added_to_po"
    )

    request.refresh_status_from_lines!

    assert_equal "added_to_po", request.reload.status
  end
end
