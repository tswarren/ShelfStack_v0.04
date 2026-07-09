# frozen_string_literal: true

require "test_helper"

class Products::ProductEntryRevampTestCase < ActiveSupport::TestCase
  setup do
    return if Format.where.not(catalog_item_type: nil).count >= 25

    require Rails.root.join("db/seeds/concerns/csv_classification_importer")
    Seeds::CsvClassificationImporter.import_formats_mvp!
  end
end

class Products::FieldVisibilityResolverTest < Products::ProductEntryRevampTestCase
  test "book print shows bisac and hides genre scheme" do
    result = Products::FieldVisibilityResolver.resolve(staff_item_kind: "book", digital: false)
    assert result[:bisac_picker].visible
    refute result[:genre_scheme_picker].visible
  end

  test "recorded music shows genre scheme and hides bisac" do
    result = Products::FieldVisibilityResolver.resolve(staff_item_kind: "recorded_music", digital: false)
    refute result[:bisac_picker].visible
    assert result[:genre_scheme_picker].visible
  end

  test "service short form hides format and digital" do
    result = Products::FieldVisibilityResolver.resolve(staff_item_kind: "service", digital: false)
    refute result[:format].visible
    refute result[:digital].visible
    assert result[:title].required
  end

  test "variable variation shows variant label 1" do
    result = Products::FieldVisibilityResolver.resolve(staff_item_kind: "book", digital: false, variation_type: "variable")
    assert result[:variant_label_1].visible
    refute result[:variant_label_2].visible
  end
end

class Products::FormatEligibilityTest < Products::ProductEntryRevampTestCase
  test "book digital excludes trade cloth" do
    assert Format.where(catalog_item_type: "book").count >= 5, "seed MVP formats in test setup"

    formats = Products::FormatEligibility.eligible_formats(catalog_item_type: "book", digital: true)
    keys = formats.pluck(:format_key)
    assert_includes keys, "ebook"
    refute_includes keys, "trade_cloth"
  end
end

class Products::OperationalTypeDeriverTest < ActiveSupport::TestCase
  test "service maps to service product type" do
    assert_equal "service", Products::OperationalTypeDeriver.derive(staff_item_kind: "service", digital: false)
  end

  test "book digital maps to digital product type" do
    assert_equal "digital", Products::OperationalTypeDeriver.derive(staff_item_kind: "book", digital: true)
  end
end

class Products::ItemKindNormalizerTest < ActiveSupport::TestCase
  test "service product shows Service label not Other" do
    product = Product.new(catalog_item_type: "other", product_type: "service")
    assert_equal "service", Products::ItemKindNormalizer.infer_staff_item_kind(product)
    assert_equal "Service", Products::ItemKindNormalizer.staff_label("service")
  end

  test "audiobook legacy normalizes to book staff kind inference path" do
    product = Product.new(catalog_item_type: "audiobook")
    assert_equal "book", Products::ItemKindNormalizer.infer_staff_item_kind(product)
  end
end

class Products::EntryContextTest < ActiveSupport::TestCase
  test "book print entry context uses bisac scheme" do
    ctx = Products::EntryContext.build(product: Product.new(catalog_item_type: "book"), staff_item_kind: "book", digital: false)
    assert_equal Bisac::CategoryNodeImporter::SCHEME_KEY, ctx.controlled_scheme
    refute ctx.short_form?
  end

  test "service entry context is short form" do
    ctx = Products::EntryContext.build(product: Product.new, staff_item_kind: "service")
    assert ctx.short_form?
    assert_equal "service", ctx.operational_product_type
  end
end

class Products::MetadataParamsSanitizerTest < ActiveSupport::TestCase
  test "new create drops hidden keys" do
    ctx = Products::EntryContext.build(product: Product.new, staff_item_kind: "service", mode: :new)
    result = Products::MetadataParamsSanitizer.sanitize(
      params: { title: "Repair", format_id: 9, publisher: "Acme" },
      entry_context: ctx,
      mode: :new
    )
    assert_equal "Repair", result[:title]
    refute result.key?(:format_id)
    refute result.key?(:publisher)
  end
end

class FormatEligibilityColumnsTest < ActiveSupport::TestCase
  test "format accepts catalog_item_type" do
    format = Format.new(
      format_key: "test_format_#{SecureRandom.hex(3)}",
      name: "Test",
      short_name: "Test",
      catalog_item_type: "book",
      digital: false,
      sort_order: 1,
      active: true
    )
    assert format.valid?, format.errors.full_messages.join(", ")
  end
end

class CategoryNodeSchemeKeyLengthTest < ActiveSupport::TestCase
  test "store categories reject node_key over 30" do
    scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |s|
      s.name = "Store Categories"
      s.purpose = CategoryNode::STORE_CATEGORIES_SCHEME_KEY
      s.active = true
    end
    node = CategoryNode.new(category_scheme: scheme, node_key: "a" * 31, name: "Too long", sort_order: 0)
    refute node.valid?
  end

  test "music genres accept long node_key" do
    scheme = CategoryScheme.find_or_create_by!(scheme_key: "music_genres") do |s|
      s.name = "Music Genres"
      s.purpose = "music_genres"
      s.active = true
    end
    key = "a" * 81
    node = CategoryNode.new(category_scheme: scheme, node_key: key, name: "Long key node", sort_order: 0)
    assert node.valid?, node.errors.full_messages.join(", ")
  end
end
