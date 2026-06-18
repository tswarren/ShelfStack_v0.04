# frozen_string_literal: true

require "test_helper"

class Items::ItemAttentionPresenterTest < ActiveSupport::TestCase
  setup do
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @variant = create_product_variant!(product: @product, selling_price_cents: 0)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )
  end

  test "flags open tbo and missing selling price" do
    items = Items::ItemAttentionPresenter.for(item: @item, store: @store, user: @user)

    assert items.any? { |item| item.message.include?("open TBO") }
    assert items.any? { |item| item.message.include?("missing a selling price") }
  end

  test "does not flag vendor without item number when vendor is assigned" do
    ProductVendor.create!(
      product: @product,
      vendor: create_vendor!,
      vendor_item_number: nil,
      active: true,
      preferred: true
    )

    items = Items::ItemAttentionPresenter.for(item: @item, store: @store, user: @user)

    assert items.none? { |item| item.message.include?("no vendor assigned") }
  end

  test "flags missing vendor assignment" do
    items = Items::ItemAttentionPresenter.for(item: @item, store: @store, user: @user)

    assert items.any? { |item| item.message.include?("no vendor assigned") }
  end
end
