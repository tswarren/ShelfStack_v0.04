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
    refute result[:preferred_vendor].visible
    refute result[:default_display_location].visible
    assert result[:title].required
  end

  test "ordinary kinds show preferred vendor and display location defaults" do
    result = Products::FieldVisibilityResolver.resolve(staff_item_kind: "book", digital: false)
    assert result[:preferred_vendor].visible
    assert result[:default_display_location].visible
    refute result[:preferred_vendor].required
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

  test "to_client_payload exposes field visibility for the form controller" do
    ctx = Products::EntryContext.build(product: Product.new(catalog_item_type: "book"), staff_item_kind: "book", digital: false)
    payload = ctx.to_client_payload

    assert_equal "book", payload[:staff_item_kind]
    assert_equal false, payload[:short_form]
    assert payload[:field_visibility][:page_count].key?(:visible)
    assert payload[:eligible_formats].is_a?(Array)
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

  test "keeps physical and format metadata keys that match form param names" do
    ctx = Products::EntryContext.build(
      product: Product.new(variation_type: "variable"),
      staff_item_kind: "book",
      digital: false,
      mode: :new
    )
    result = Products::MetadataParamsSanitizer.sanitize(
      params: {
        title: "Heavy Book",
        height: "2.5",
        width: "6.0",
        depth: "9.0",
        dimension_units: "in",
        weight: "16",
        weight_units: "oz",
        language_code: "eng",
        variant1_label: "Size",
        series_name: "Saga",
        series_enumeration: "1"
      },
      entry_context: ctx,
      mode: :new
    )

    assert_equal "2.5", result[:height]
    assert_equal "in", result[:dimension_units]
    assert_equal "eng", result[:language_code]
    assert_equal "Size", result[:variant1_label]
    assert_equal "Saga", result[:series_name]
    assert_equal "1", result[:series_enumeration]
  end

  test "edit drops hidden submitted keys" do
    product = Product.new(
      catalog_item_type: "book",
      product_type: "physical",
      variation_type: "standard",
      publisher: "Saved Publisher"
    )
    ctx = Products::EntryContext.build(product: product, staff_item_kind: "service", mode: :edit)
    result = Products::MetadataParamsSanitizer.sanitize(
      params: { title: "Repair", publisher: "Evil Override", format_id: 9 },
      entry_context: ctx,
      mode: :edit
    )
    assert_equal "Repair", result[:title]
    refute result.key?(:publisher)
    refute result.key?(:format_id)
  end

  test "edit kind change sets classification cleanup flag and drops invalid picker keys" do
    product = Product.new(catalog_item_type: "book", product_type: "physical", variation_type: "conditional")
    ctx = Products::EntryContext.build(product: product, staff_item_kind: "recorded_music", mode: :edit)
    result = Products::MetadataParamsSanitizer.sanitize(
      params: {
        title: "Album",
        primary_bisac_category_node_id: 11,
        bisac_category_node_ids: [ 12 ],
        primary_genre_category_node_id: 21
      },
      entry_context: ctx,
      mode: :edit,
      item_kind_changed: true
    )

    assert_equal true, result[:_classification_cleanup]
    assert_equal 21, result[:primary_genre_category_node_id]
    refute result.key?(:primary_bisac_category_node_id)
    refute result.key?(:bisac_category_node_ids)
  end

  test "edit without kind change does not set classification cleanup" do
    product = Product.new(catalog_item_type: "book", product_type: "physical", variation_type: "conditional")
    ctx = Products::EntryContext.build(product: product, staff_item_kind: "book", mode: :edit)
    result = Products::MetadataParamsSanitizer.sanitize(
      params: { title: "Still a Book" },
      entry_context: ctx,
      mode: :edit,
      item_kind_changed: false
    )

    refute result.key?(:_classification_cleanup)
  end
end

class Products::FieldKeyRegistryTest < ActiveSupport::TestCase
  test "param map keys are a subset of visibility field keys" do
    assert Products::FieldKeyRegistry.consistent?,
           "Unmapped drift keys: #{Products::FieldKeyRegistry.drift_keys.inspect}"
  end
end

class Products::MetadataPreviewParamsTest < ActiveSupport::TestCase
  test "filters to assignable visible attributes and drops picker keys" do
    ctx = Products::EntryContext.build(product: Product.new, staff_item_kind: "book", mode: :new)
    result = Products::MetadataPreviewParams.filter(
      params: {
        title: "Preview Title",
        publisher: "Pub",
        staff_item_kind: "book",
        primary_bisac_category_node_id: 99,
        unknown_junk: "nope"
      },
      entry_context: ctx,
      mode: :new
    )

    assert_equal "Preview Title", result[:title]
    assert_equal "Pub", result[:publisher]
    refute result.key?(:primary_bisac_category_node_id)
    refute result.key?(:staff_item_kind)
    refute result.key?(:unknown_junk)
  end

  test "does not assign hidden keys for short form" do
    ctx = Products::EntryContext.build(product: Product.new, staff_item_kind: "service", mode: :new)
    result = Products::MetadataPreviewParams.filter(
      params: { title: "Repair", publisher: "Should Drop", format_id: 3 },
      entry_context: ctx,
      mode: :new
    )

    assert_equal "Repair", result[:title]
    refute result.key?(:publisher)
    refute result.key?(:format_id)
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

class CategoryNodeMatchingNameOrKeyTest < ActiveSupport::TestCase
  test "matching_name_or_key is case insensitive without ILIKE" do
    scheme = CategoryScheme.find_or_create_by!(scheme_key: "test_genres_#{SecureRandom.hex(3)}") do |s|
      s.name = "Test Genres"
      s.purpose = "music_genres"
      s.active = true
    end
    node = CategoryNode.create!(
      category_scheme: scheme,
      node_key: "jazz_fusion",
      name: "Jazz Fusion",
      sort_order: 0,
      active: true
    )

    assert_includes CategoryNode.matching_name_or_key("jazz"), node
    assert_includes CategoryNode.matching_name_or_key("FUSION"), node
    assert_includes CategoryNode.matching_name_or_key("jazz_fusion"), node
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
