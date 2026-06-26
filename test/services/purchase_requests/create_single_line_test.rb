# frozen_string_literal: true

require "test_helper"

class PurchaseRequests::CreateSingleLineTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
  end

  test "creates single-line purchase request" do
    request = PurchaseRequests::CreateSingleLine.call!(
      store: @store,
      product_variant: @variant,
      created_by_user: @user,
      requested_quantity: 2,
      request_reason: "tbo"
    )

    assert_equal 1, request.purchase_request_lines.size
    assert_equal 2, request.purchase_request_lines.first.requested_quantity
    assert AuditEvent.exists?(event_name: "purchase_request.created", auditable: request)
  end

  test "blocks financial product for tbo" do
    @variant.product.update!(product_type: "financial")

    assert_raises(PurchaseRequests::CreateSingleLine::CreateError) do
      PurchaseRequests::CreateSingleLine.call!(
        store: @store,
        product_variant: @variant,
        created_by_user: @user
      )
    end
  end
end
