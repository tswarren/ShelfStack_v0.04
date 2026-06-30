# frozen_string_literal: true

require "test_helper"

module Products
  class CopyCategorizationsFromCatalogItemTest < ActiveSupport::TestCase
    include Phase3TestHelper

    setup do
      scheme = CategoryScheme.create!(scheme_key: "test_bisac_copy", name: "Test BISAC", purpose: "bisac", active: true)
      @node = CategoryNode.create!(
        category_scheme: scheme,
        node_key: "FIC_COPY",
        name: "Fiction Copy Test",
        sort_order: 1,
        active: true
      )
      @catalog_item = create_catalog_item!(title: "Categorization Copy Book")
      @categorization = Categorization.create!(
        categorizable: @catalog_item,
        category_node: @node,
        primary: true,
        source: "manual"
      )
    end

    test "copy_catalog_to_product duplicates without repointing catalog row" do
      product = create_product!(catalog_item: @catalog_item)

      CopyCategorizationsFromCatalogItem.to_product(product, @catalog_item)

      assert Categorization.exists?(categorizable: @catalog_item, category_node_id: @node.id)
      assert Categorization.exists?(categorizable: product, category_node_id: @node.id)
      assert_not_equal @categorization.id, product.categorizations.find_by!(category_node_id: @node.id).id
    end

    test "copy_catalog_to_product gives each linked product its own copy" do
      product_one = create_product!(catalog_item: @catalog_item, sku: "COPY-PROD-001")
      product_two = Product.create!(
        catalog_item: @catalog_item,
        title: @catalog_item.title,
        name: @catalog_item.title,
        catalog_item_type: "book",
        publication_status: "active",
        sku: "COPY-PROD-002",
        product_type: "physical",
        variation_type: "standard",
        list_price_cents: 1000,
        active: true
      )

      CopyCategorizationsFromCatalogItem.to_product(product_one, @catalog_item)
      CopyCategorizationsFromCatalogItem.to_product(product_two, @catalog_item)

      assert Categorization.exists?(categorizable: @catalog_item, category_node_id: @node.id)
      assert Categorization.exists?(categorizable: product_one, category_node_id: @node.id)
      assert Categorization.exists?(categorizable: product_two, category_node_id: @node.id)
    end

    test "sync_bidirectional restores catalog row after repoint and copies to product" do
      product = create_product!(catalog_item: @catalog_item)
      @categorization.update_columns(categorizable_type: "Product", categorizable_id: product.id, updated_at: Time.current)

      assert_not Categorization.exists?(categorizable: @catalog_item, category_node_id: @node.id)

      CopyCategorizationsFromCatalogItem.sync_product_and_catalog(product, @catalog_item)

      assert Categorization.exists?(categorizable: @catalog_item, category_node_id: @node.id)
      assert Categorization.exists?(categorizable: product, category_node_id: @node.id)
    end

    test "sync is idempotent" do
      product = create_product!(catalog_item: @catalog_item)

      2.times do
        CopyCategorizationsFromCatalogItem.sync_product_and_catalog(product, @catalog_item)
      end

      assert_equal 1, Categorization.where(categorizable: @catalog_item, category_node_id: @node.id).count
      assert_equal 1, Categorization.where(categorizable: product, category_node_id: @node.id).count
    end
  end
end
