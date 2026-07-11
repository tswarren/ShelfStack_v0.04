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

  test "create catalog linked product defaults sku and seeds identifier" do
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
    assert_equal @catalog_item.title, product.name
    assert_equal "standard", product.variation_type
    assert product.sku.present?
    assert product.primary_identifier.present?
    assert_equal product.sku, product.primary_identifier.normalized_identifier
    assert AuditEvent.exists?(event_name: "product.created", auditable: product)
  end

  test "edit metadata redirects to unified edit product" do
    product = create_product!(
      skip_product_identifier: true,
      title: "Metadata Edit Book",
      catalog_item_type: "book",
      publication_status: "active"
    )

    get edit_metadata_items_product_path(product, return_to: "item")
    assert_redirected_to edit_items_product_path(product, return_to: "item")
  end

  test "update product metadata for fused product" do
    product = create_product!(
      skip_product_identifier: true,
      title: "Metadata Edit Book",
      catalog_item_type: "book",
      publication_status: "active"
    )

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        staff_item_kind: "book",
        title: "Updated Metadata Title",
        format_id: product.format_id,
        publication_status: "active",
        active: true,
        creators: "New Author"
      }
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    product.reload
    assert_equal "Updated Metadata Title", product.title
    assert_equal "New Author", product.creators
    assert AuditEvent.exists?(event_name: "product.updated", auditable: product)
  end

  test "edit product form mounts canonical picker inputs and context wiring" do
    product = create_product!(
      skip_product_identifier: true,
      title: "Picker Shell Book",
      catalog_item_type: "book",
      publication_status: "active"
    )

    get edit_items_product_path(product, return_to: "item")

    assert_response :success
    assert_includes response.body, 'data-product-canonical-inputs="bisac_picker"'
    assert_includes response.body, 'data-product-canonical-inputs="genre_scheme_picker"'
    assert_includes response.body, 'data-product-field-key="bisac_picker"'
    assert_includes response.body, items_product_entry_context_path
    assert_not_includes response.body, "data-product-metadata-form-preview-url-value"
  end

  test "update metadata validation failure re-renders submitted visible values" do
    product = create_product!(
      skip_product_identifier: true,
      title: "Original Title",
      catalog_item_type: "book",
      publication_status: "active",
      description: "Original description"
    )

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        staff_item_kind: "book",
        title: "Submitted New Title",
        description: "Submitted description",
        publication_status: "not_a_real_status",
        active: true
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Submitted New Title"
    assert_includes response.body, "Submitted description"
    assert_equal "Original Title", product.reload.title
  end

  test "changing item kind on metadata save clears incompatible BISAC categorizations" do
    seed_bisac_scheme!
    product = create_product!(
      skip_product_identifier: true,
      title: "Kind Change Book",
      catalog_item_type: "book",
      publication_status: "active"
    )
    general = CategoryNode.find_by!(node_key: "fic000000")
    ProductBisacSync.sync!(
      product: product,
      primary_bisac_category_node_id: general.id,
      bisac_category_node_ids: [],
      structured: true
    )
    assert product.bisac_categorizations.exists?

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        staff_item_kind: "recorded_music",
        title: "Kind Change Album",
        publication_status: "active",
        active: true
      },
      primary_bisac_category_node_id: general.id
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    product.reload
    assert_equal "recorded_music", Products::ItemKindNormalizer.infer_staff_item_kind(product)
    assert_not product.bisac_categorizations.exists?
  end

  test "edit metadata redirects legacy catalog linked products to edit product" do
    product = create_legacy_catalog_linked_product!

    get edit_metadata_items_product_path(product, return_to: "item")

    assert_redirected_to edit_items_product_path(product, return_to: "item")
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

  test "update product with return_to item redirects to selling tab" do
    product = create_product!

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        name_override: "Custom Override",
        sku: product.sku,
        product_type: product.product_type,
        list_price_cents: 2499,
        active: true
      }
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert_equal 2499, product.reload.list_price_cents
  end

  test "catalog linked update allows variation_type changes" do
    product = create_product!(variation_type: "conditional")

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        sku: product.sku,
        product_type: product.product_type,
        variation_type: "matrix",
        variant1_label: "Size",
        variant2_label: "Color",
        list_price_cents: product.list_price_cents,
        active: true
      }
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    assert_equal "matrix", product.reload.variation_type
    assert_equal "Size", product.variant1_label
    assert_equal "Color", product.variant2_label
  end

  test "catalog linked edit includes variation label fields and product metadata form controller" do
    product = create_product!(
      variation_type: "matrix",
      variant1_label: "Size",
      variant2_label: "Color"
    )

    get edit_items_product_path(product)

    assert_response :success
    assert_includes response.body, 'data-controller="product-metadata-form"'
    assert_includes response.body, "variant1_label"
    assert_includes response.body, "variant2_label"
    assert_includes response.body, 'data-product-metadata-form-target="variationType"'
    assert_includes response.body, 'data-product-field-key="variant_label_1"'
    assert_includes response.body, 'data-product-field-key="variant_label_2"'
    assert_select "select[name=\"product[variation_type]\"]", count: 1
    assert_select "select[name=\"product[product_type]\"]", count: 0
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

  test "update product ignores submitted sku on normal product form" do
    product = create_product!(sku: "OLDSKU-001", skip_product_identifier: true)

    patch items_product_path(product, return_to: "item"), params: {
      product: {
        title: product.title.presence || product.name,
        name: product.name,
        sku: "9780123456789",
        product_type: product.product_type,
        variation_type: product.variation_type,
        list_price_cents: product.list_price_cents,
        active: true
      }
    }

    assert_redirected_to items_item_path(product_id: product.id, tab: "item_setup")
    product.reload
    assert_equal "OLDSKU-001", product.sku
    assert_nil product.primary_identifier
  end
end
