# frozen_string_literal: true

require "test_helper"

class Items::ItemOperationsTabPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @vendor = create_vendor!
    @product = create_product!
    @variant = create_product_variant!(product: @product)
    @item = Items::ItemPresenter.from_product(@product)
    @request = PurchaseRequest.create!(store: @store, status: "open")
    @request.purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 3,
      status: "open"
    )
  end

  test "lists open purchase request lines for item variants" do
    presenter = Items::ItemOperationsTabPresenter.new(
      item: @item,
      store: @store,
      user: @user
    )

    assert_equal 1, presenter.open_purchase_request_lines.size
    assert_equal @variant.id, presenter.open_purchase_request_lines.first.product_variant_id
  end
end
