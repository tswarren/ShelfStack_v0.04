# frozen_string_literal: true

require "test_helper"

class IngramCatalogImport::RunnerTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @actor = create_user!
    @category = create_category!
    @options = IngramCatalogImport::ImportOptions.new(default_category: @category)
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
    assert_equal "9780063575011", item.primary_identifier.normalized_identifier
    assert item.products.active_records.exists?
    assert item.products.active_records.first.product_variants.active_records.exists?
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

    assert @result.count(:variant_matched).positive?
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
end
