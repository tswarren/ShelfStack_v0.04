# frozen_string_literal: true

require "test_helper"

class ItemsItemPresenterTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "from catalog item resolves linked product" do
    product = create_product!
    presenter = Items::ItemPresenter.from_catalog_item(product.catalog_item)

    assert_equal product.catalog_item.title, presenter.title
    assert_equal product, presenter.product
  end

  test "from product variant normalizes to parent product" do
    variant = create_product_variant!
    presenter = Items::ItemPresenter.from_product_variant(variant)

    assert_equal variant.product, presenter.product
  end

  test "non catalog product uses product anchor" do
    product = Product.create!(
      name: "Gift Card",
      sku: "GIFT-001",
      product_type: "financial",
      variation_type: "standard",
      list_price_cents: 0,
      active: true
    )
    presenter = Items::ItemPresenter.from_product(product)

    assert_nil presenter.catalog_item
    assert_equal "Gift Card", presenter.title
  end

  test "format name returns short format label for search" do
    product = create_product!
    presenter = Items::ItemPresenter.from_catalog_item(product.catalog_item)

    assert_equal product.catalog_item.format.name, presenter.format_name
  end

  test "tab path appends tab query param without breaking anchor param" do
    product = create_product!
    presenter = Items::ItemPresenter.from_catalog_item(product.catalog_item)

    assert_equal "/items/item?catalog_item_id=#{product.catalog_item.id}&tab=item_setup", presenter.tab_path("item_setup")
    assert_equal "/items/item?catalog_item_id=#{product.catalog_item.id}", presenter.tab_path("overview")
  end

  test "variant summary label lists active condition names" do
    product = create_product!
    variant = create_product_variant!(product: product)
    presenter = Items::ItemPresenter.from_product(product)

    assert_includes presenter.variant_summary_label, variant.condition.short_name
  end

  test "price range label formats min and max selling prices" do
    product = create_product!
    sub_department = create_sub_department!
    create_product_variant!(product: product, sub_department: sub_department, selling_price_cents: 1299)
    used = ProductCondition.find_by(condition_key: "used") || create_product_condition!(condition_key: "used", short_name: "Used", new_condition: false, sku_component: "U")
    create_product_variant!(product: product, sub_department: sub_department, condition: used, sku: "#{product.sku}-U", selling_price_cents: 899)
    presenter = Items::ItemPresenter.from_product(product.reload)

    assert_equal "$8.99 – $12.99", presenter.price_range_label
  end

  test "search statuses omit invalid identifier warning" do
    item = create_catalog_item!
    CatalogIdentifierService.add_identifier!(
      catalog_item: item,
      identifier_type: "isbn13",
      value: "9780123456780",
      primary: false
    )
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_includes presenter.basic_statuses, "invalid_identifier_warning"
    assert_not_includes presenter.search_statuses, "invalid_identifier_warning"
    assert_includes presenter.search_statuses, "catalog_only"
  end

  test "context actions include edit catalog" do
    product = create_product!
    presenter = Items::ItemPresenter.from_product(product)

    labels = presenter.context_actions.map { |action| action[:label] }

    assert_includes labels, "Edit Catalog"
  end

  test "overview actions include edit catalog item and edit product" do
    product = create_product!
    presenter = Items::ItemPresenter.from_product(product)

    labels = presenter.overview_actions.map { |action| action[:label] }

    assert_equal [ "Edit Catalog Item", "Edit Product" ], labels
  end

  test "creator entries parse display names and roles" do
    item = create_catalog_item!(creators: "Tolkien, J.R.R. [author]; Lee, Harper [author;editor]")
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal 2, presenter.creator_entries.size
    assert_equal "Tolkien, J.R.R.", presenter.creator_entries.first["display_name"]
    assert_equal [ "author" ], presenter.creator_entries.first["roles"]
    assert_equal %w[author editor], presenter.creator_entries.second["roles"]
  end

  test "subject headings omit scheme and code metadata" do
    item = create_catalog_item!(bisac_subjects: "Fiction / General [bisac/FIC000000]; Mystery [local]")
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal [ "Fiction / General", "Mystery" ], presenter.subject_headings
  end

  test "subject headings strip non scheme bracket labels" do
    item = create_catalog_item!(genres: "Science Fiction [sci-fi]; Historical [period]")
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal [ "Science Fiction", "Historical" ], presenter.subject_headings
  end

  test "subject headings combine bisac genres and themes" do
    item = create_catalog_item!(
      bisac_subjects: "Fiction / General [bisac/FIC000000]",
      genres: "Adventure",
      themes: "Coming of Age [theme]"
    )
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal [ "Fiction / General", "Adventure", "Coming of Age" ], presenter.subject_headings
  end

  test "subject groups preserve headings by type" do
    item = create_catalog_item!(
      bisac_subjects: "Fiction / General [bisac/FIC000000]",
      genres: "Adventure",
      themes: "Coming of Age [theme]"
    )
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_equal [ "Subjects", "Genres", "Themes" ], presenter.subject_groups.pluck(:label)
    assert_equal [ "Fiction / General" ], presenter.subject_groups.first[:headings]
  end

  test "catalog facts use format name without code and separate release date" do
    format = create_format!(name: "Hardcover", code: "HC")
    item = create_catalog_item!(format: format, publication_date: Date.new(2024, 3, 15), publication_status: "active")
    presenter = Items::ItemPresenter.from_catalog_item(item)
    facts = presenter.catalog_facts.to_h

    assert_equal "Hardcover", facts["Format"]
    assert_equal "March 15, 2024", facts["Released"]
    assert_equal "Active", presenter.publication_status_label
  end

  test "display location path returns ancestor chain from product default" do
    store_floor = create_display_location!(name: "Store Floor", short_name: "Floor #{SecureRandom.hex(2)}")
    fiction = create_display_location!(name: "Fiction", short_name: "Fic #{SecureRandom.hex(2)}", parent: store_floor)
    shelf = create_display_location!(name: "Shelf A", short_name: "Shlf #{SecureRandom.hex(2)}", parent: fiction)
    product = create_product!(default_display_location: shelf)
    presenter = Items::ItemPresenter.from_product(product)

    assert_equal [ "Store Floor", "Fiction", "Shelf A" ], presenter.display_location_path.map(&:name)
  end

  test "display location path prefers highlighted variant location" do
    default = create_display_location!(name: "Default Section", short_name: "Def #{SecureRandom.hex(2)}")
    variant_location = create_display_location!(name: "Signed Table", short_name: "Sig #{SecureRandom.hex(2)}")
    product = create_product!(default_display_location: default)
    variant = create_product_variant!(product: product, display_location: variant_location)
    presenter = Items::ItemPresenter.from_product(product)

    assert_equal [ "Signed Table" ], presenter.display_location_path(variant: variant).map(&:name)
  end
end
