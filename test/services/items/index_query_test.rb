# frozen_string_literal: true

require "test_helper"

module Items
  class IndexQueryTest < ActiveSupport::TestCase
    include Phase3TestHelper

    test "browse all includes catalog and non-catalog products" do
      catalog_item = create_catalog_item!(title: "Browse Catalog Alpha")
      create_product!(catalog_item: catalog_item)

      non_catalog = Product.create!(
        title: "Browse Non-Catalog Gift",
        name: "Browse Non-Catalog Gift",
        catalog_item_type: "gift",
        publication_status: "active",
        sku: "BROWSE-GIFT-001",
        product_type: "financial",
        variation_type: "standard",
        list_price_cents: 2500,
        active: true
      )
      create_product_variant!(product: non_catalog, sku: non_catalog.sku)

      titles = Items::IndexQuery.call.results.map { |result| result.presenter.title }

      assert_includes titles, "Browse Catalog Alpha"
      assert_includes titles, "Browse Non-Catalog Gift"
    end

    test "finds product by series name" do
      item = create_catalog_item!(title: "Indexed Series Book", series_name: "Mystery River")
      product = create_product!(catalog_item: item)
      result = Items::IndexQuery.call(query: "Mystery River")

      assert result.results.any? { |entry| entry.presenter.product == product }
    end

    test "finds product by categorization subject word" do
      scheme = CategoryScheme.create!(scheme_key: "test_bisac", name: "Test BISAC", purpose: "bisac", active: true)
      node = CategoryNode.create!(
        category_scheme: scheme,
        node_key: "FIC_FANT",
        name: "Fantasy Adventure Fiction",
        sort_order: 1,
        active: true
      )
      item = create_catalog_item!(title: "Hidden Fantasy Title")
      product = create_product!(catalog_item: item)
      Categorization.create!(categorizable: product, category_node: node, source: "manual")

      result = Items::IndexQuery.call(query: "Fantasy Adventure")

      assert result.results.any? { |entry| entry.presenter.product == product }
    end

    test "filters by format" do
      hardcover = Format.find_by(format_key: "hardcover") || create_format!(format_key: "hardcover", name: "Hardcover")
      paperback = create_format!(format_key: "pbk_filter", name: "Paperback Filter Test")
      matching = create_catalog_item!(title: "Hardcover Only Item", format: hardcover)
      create_product!(catalog_item: matching)
      create_catalog_item!(title: "Paperback Only Item", format: paperback)

      results = Items::IndexQuery.call(format_id: hardcover.id).results

      assert results.any? { |entry| entry.presenter.title == "Hardcover Only Item" }
      assert_not results.any? { |entry| entry.presenter.title == "Paperback Only Item" }
    end

    test "include inactive shows inactivated product" do
      item = create_catalog_item!(title: "Inactive Browse Item")
      product = create_product!(catalog_item: item)
      product.inactivate!

      active_results = Items::IndexQuery.call(query: "Inactive Browse Item").results
      inactive_results = Items::IndexQuery.call(query: "Inactive Browse Item", include_inactive: true).results

      assert_empty active_results
      assert inactive_results.any? { |entry| entry.presenter.product == product }
    end

    test "paginates browse results" do
      30.times do |index|
        item = create_catalog_item!(title: "Paginated Item #{index.to_s.rjust(2, '0')}")
        create_product!(catalog_item: item)
      end

      page_one = Items::IndexQuery.call(page: 1, per_page: 25)
      page_two = Items::IndexQuery.call(page: 2, per_page: 25)

      assert_equal 25, page_one.results.size
      assert page_two.results.size >= 5
      assert_operator page_one.total_count, :>=, 30
      assert_not_equal page_one.results.first.presenter.title, page_two.results.first.presenter.title
    end

    test "filters by store category including child categories" do
      scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |record|
        record.name = "Store Categories"
        record.purpose = "store_categories"
        record.active = true
      end
      suffix = SecureRandom.hex(3)
      parent = CategoryNode.create!(
        category_scheme: scheme,
        node_key: "parent_fic_#{suffix}",
        name: "Parent Fiction #{suffix}",
        sort_order: 1,
        active: true
      )
      child = CategoryNode.create!(
        category_scheme: scheme,
        parent: parent,
        node_key: "child_fic_#{suffix}",
        name: "Child Mystery #{suffix}",
        sort_order: 1,
        active: true
      )
      sibling = CategoryNode.create!(
        category_scheme: scheme,
        node_key: "other_fic_#{suffix}",
        name: "Other Sci-Fi #{suffix}",
        sort_order: 2,
        active: true
      )

      in_child = create_catalog_item!(title: "Child Category Book #{suffix}", store_category: child)
      create_product!(catalog_item: in_child)
      create_catalog_item!(title: "Sibling Category Book #{suffix}", store_category: sibling)

      results = Items::IndexQuery.call(store_category_id: parent.id, query: suffix).results
      titles = results.map { |entry| entry.presenter.title }

      assert_includes titles, "Child Category Book #{suffix}"
      assert_not_includes titles, "Sibling Category Book #{suffix}"
      assert_equal in_child.title, results.find { |entry| entry.presenter.title == "Child Category Book #{suffix}" }.presenter.product.title
    end

    test "dedupes variant hits to one presenter" do
      variant = create_product_variant!(sku: "INDEXVARIANTSKU")
      results = Items::IndexQuery.call(query: "INDEXVARIANTSKU").results

      assert_equal 1, results.size
      assert_equal variant.product, results.first.presenter.product
    end
  end
end
