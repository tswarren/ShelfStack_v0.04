# frozen_string_literal: true

require "test_helper"

class ItemsProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "productadmin", password: "Password123!")
    grant_permission!(@admin, "items.access")
    %w[
      items.products.view items.products.create items.products.update
      items.products.inactivate items.products.reactivate items.products.delete
    ].each { |key| grant_permission!(@admin, key) }
    @catalog_item = create_catalog_item!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "productadmin", password: "Password123!" }
  end

  test "create catalog linked product defaults sku from primary identifier" do
    post items_products_path, params: {
      product: {
        catalog_item_id: @catalog_item.id,
        product_type: "physical",
        variation_type: "standard",
        list_price_cents: 1999,
        active: true
      }
    }

    product = Product.order(:id).last
    assert_equal @catalog_item.primary_identifier.normalized_identifier, product.sku
    assert_equal @catalog_item.title, product.name
    assert AuditEvent.exists?(event_name: "product.created", auditable: product)
  end

  test "update product with cover image" do
    product = create_product!
    cover = fixture_file_upload("cover.png", "image/png")

    patch items_product_path(product), params: {
      product: {
        name: product.name,
        sku: product.sku,
        product_type: product.product_type,
        variation_type: product.variation_type,
        list_price_cents: product.list_price_cents,
        active: true,
        cover_image: cover
      }
    }

    assert_redirected_to items_product_path(product)
    assert product.reload.cover_image.attached?
  end

  test "update product can remove cover image" do
    product = create_product!
    product.cover_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/cover.png")),
      filename: "cover.png",
      content_type: "image/png"
    )

    patch items_product_path(product), params: {
      product: {
        name: product.name,
        sku: product.sku,
        product_type: product.product_type,
        variation_type: product.variation_type,
        list_price_cents: product.list_price_cents,
        active: true,
        remove_cover_image: "1"
      }
    }

    assert_redirected_to items_product_path(product)
    assert_not product.reload.cover_image.attached?
  end
end
