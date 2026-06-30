# frozen_string_literal: true

require "test_helper"

class IngramCatalogImport::RunnerTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @actor = create_user!
    @sub_department = create_sub_department!
    @options = IngramCatalogImport::ImportOptions.new(
      default_sub_department: @sub_department,
      default_store_category: store_category_node_for_tests
    )
    @fixture_path = Rails.root.join("test/fixtures/files/ingram_list_sample.xls").to_s
  end

  test "imports rows from sample file" do
    result = IngramCatalogImport::Runner.call(
      path: @fixture_path,
      actor: @actor,
      options: @options
    )

    assert result.total_rows.positive?
    assert result.count(:variant_created).positive?
    assert result.count(:error).zero?
    assert AuditEvent.exists?(event_name: "ingram_import.completed")

    item = CatalogItem.find_by!(title: "Communion: Finding My Way Back to Faith")
    product = item.products.active_records.first!
    assert_equal "9780063575011", product.primary_identifier.normalized_identifier
    assert product.product_variants.active_records.exists?
  end

  test "imports rows and links bisac subject when tree is loaded" do
    seed_bisac_scheme!
    scheme = CategoryScheme.find_by!(scheme_key: "bisac")
    node = scheme.category_nodes.create!(
      node_key: "ingramtest",
      name: "Biography & Autobiography / Presidents & Heads of State",
      sort_order: 99,
      active: true
    )

    IngramCatalogImport::Runner.call(
      path: @fixture_path,
      actor: @actor,
      options: @options
    )

    item = CatalogItem.find_by!(title: "Communion: Finding My Way Back to Faith")
    assert item.bisac_categorizations.exists?(category_node_id: node.id)
    assert_includes item.bisac_subjects, node.name
  end

  test "re-import updates catalog and product without overwriting variant" do
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: @options)

    product = Product.joins(:catalog_item).find_by!(catalog_items: { title: "Communion: Finding My Way Back to Faith" })
    variant = product.product_variants.active_records.first
    original_sku = variant.sku
    original_price = variant.selling_price_cents
    variant.update!(selling_price_cents: 1234)

    assert_no_difference -> { ProductVariant.count } do
      @result = IngramCatalogImport::Runner.call(
        path: @fixture_path,
        actor: @actor,
        options: @options
      )
    end

    assert @result.count(:variant_matched).positive?, @result.outcomes.map { |o| [ o.status, o.message ] }.inspect
    variant.reload
    assert_equal original_sku, variant.sku
    assert_equal 1234, variant.selling_price_cents
    assert_not_equal original_price, variant.selling_price_cents if original_price != 1234
    assert_equal 3500, product.reload.list_price_cents
  end

  test "matches existing new variant on second import" do
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: @options)
    first_variant_count = ProductVariant.count

    result = IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: @options)

    assert_equal first_variant_count, ProductVariant.count
    assert result.count(:variant_matched).positive?
  end

  test "assigns preferred vendor on existing product when set_preferred_vendor enabled" do
    ingram = Vendor.create!(name: "Ingram", active: true, default_supplier_discount_bps: 4000)
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: @options)

    product = Product.joins(:catalog_item).find_by!(catalog_items: { title: "Communion: Finding My Way Back to Faith" })
    assert_nil product.preferred_vendor_id

    options = IngramCatalogImport::ImportOptions.new(
      default_sub_department: @sub_department,
      default_store_category: store_category_node_for_tests,
      set_preferred_vendor: true,
      create_or_update_vendor_sources: true
    )
    result = IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: options)

    assert_equal ingram.id, product.reload.preferred_vendor_id
    assert result.preferred_vendor_assignments.positive?
    assert ProductVendor.exists?(product: product, vendor: ingram)
  end

  test "creates vendor sources without setting preferred vendor when disabled" do
    ingram = Vendor.create!(name: "Ingram", active: true, default_supplier_discount_bps: 4000)
    options = IngramCatalogImport::ImportOptions.new(
      default_sub_department: @sub_department,
      default_store_category: store_category_node_for_tests,
      set_preferred_vendor: false,
      create_or_update_vendor_sources: true
    )
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: options)

    product = Product.joins(:catalog_item).find_by!(catalog_items: { title: "Communion: Finding My Way Back to Faith" })
    variant = product.product_variants.active_records.first

    assert_nil product.preferred_vendor_id
    assert ProductVendor.exists?(product: product, vendor: ingram)
    assert ProductVariantVendor.exists?(product_variant: variant, vendor: ingram)
  end

  test "does not increment skipped when variant finalizes after product preferred vendor assigned" do
    ingram = Vendor.create!(name: "Ingram", active: true, default_supplier_discount_bps: 4000)
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: @options)

    options = IngramCatalogImport::ImportOptions.new(
      default_sub_department: @sub_department,
      default_store_category: store_category_node_for_tests,
      set_preferred_vendor: true,
      create_or_update_vendor_sources: true
    )
    result = IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: options)

    assert result.preferred_vendor_assignments.positive?
    assert_equal 0, result.preferred_vendor_skipped
    product = Product.joins(:catalog_item).find_by!(catalog_items: { title: "Communion: Finding My Way Back to Faith" })
    variant = product.product_variants.active_records.first
    assert_equal ingram.id, product.preferred_vendor_id
    assert_equal ingram.id, variant.preferred_vendor_id
  end

  test "reactivates inactive ingram vendor sources on re-import" do
    ingram = Vendor.create!(name: "Ingram", active: true, default_supplier_discount_bps: 4000)
    options = IngramCatalogImport::ImportOptions.new(
      default_sub_department: @sub_department,
      default_store_category: store_category_node_for_tests,
      set_preferred_vendor: false,
      create_or_update_vendor_sources: true
    )
    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: options)

    product = Product.joins(:catalog_item).find_by!(catalog_items: { title: "Communion: Finding My Way Back to Faith" })
    variant = product.product_variants.active_records.first
    product_vendor = ProductVendor.find_by!(product: product, vendor: ingram)
    variant_vendor = ProductVariantVendor.find_by!(product_variant: variant, vendor: ingram)
    product_vendor.update!(active: false)
    variant_vendor.update!(active: false)

    IngramCatalogImport::Runner.call(path: @fixture_path, actor: @actor, options: options)

    assert product_vendor.reload.active?
    assert variant_vendor.reload.active?
  end
end
