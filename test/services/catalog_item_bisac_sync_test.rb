# frozen_string_literal: true

require "test_helper"

class CatalogItemBisacSyncTest < ActiveSupport::TestCase
  setup do
    seed_bisac_scheme!
    @item = create_catalog_item!
    @general = CategoryNode.find_by!(node_key: "fic000000")
    @fantasy = CategoryNode.find_by!(node_key: "fic009000")
    @contemporary = CategoryNode.find_by!(node_key: "fic009010")
  end

  test "syncs structured selections with one primary subject" do
    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      primary_bisac_category_node_id: @general.id,
      bisac_category_node_ids: [ @fantasy.id ],
      structured: true
    )

    assert_not result.skipped
    assert_equal 2, result.linked_count
    assert_equal @general.id, @item.primary_bisac_categorization.category_node_id
    assert_includes @item.bisac_subjects, "Fiction / General [bisac/FIC000000]"
    assert_includes @item.bisac_subjects, "Fiction / Fantasy / General [bisac/FIC009000]"
    assert_equal "bisac", @item.bisac_subject_data.first["scheme"]
  end

  test "syncs from coded subject string" do
    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      bisac_subjects: "Fiction / Fantasy / Contemporary [bisac/FIC009010]",
      structured: false
    )

    assert_equal 1, result.linked_count
    assert_equal @contemporary.id, @item.primary_bisac_categorization.category_node_id
    assert_equal "FIC009010", @item.bisac_subject_data.first["code"]
  end

  test "syncs from heading-only subject string" do
    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      bisac_subjects: "Fiction / General",
      structured: false
    )

    assert_equal 1, result.linked_count
    assert_equal @general.id, @item.primary_bisac_categorization.category_node_id
  end

  test "syncs from ingram-style pipe-separated heading" do
    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      bisac_subjects: "Fiction | General",
      structured: false
    )

    assert_equal 1, result.linked_count
    assert_equal @general.id, @item.primary_bisac_categorization.category_node_id
  end

  test "preserves unresolved advanced paste entries as local subjects" do
    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      bisac_subjects: "Fiction / General; Store Pick [local]",
      structured: false
    )

    assert_equal 1, result.linked_count
    assert_includes result.unresolved_entries, "Store Pick"
    assert_equal 2, @item.bisac_subject_data.size
    assert_equal "local", @item.bisac_subject_data.last["scheme"]
    assert_includes @item.bisac_subjects, "Store Pick"
  end

  test "clears bisac categorizations when structured selections are empty" do
    CatalogItemBisacSync.sync!(
      catalog_item: @item,
      primary_bisac_category_node_id: @general.id,
      structured: true
    )

    CatalogItemBisacSync.sync!(
      catalog_item: @item,
      primary_bisac_category_node_id: nil,
      bisac_category_node_ids: [],
      structured: true
    )

    assert_equal 0, @item.bisac_categorizations.count
    assert_nil @item.reload.bisac_subjects
  end

  test "returns skipped result when bisac tree is not loaded" do
    CategoryScheme.find_by!(scheme_key: "bisac").update!(active: false)

    result = CatalogItemBisacSync.sync!(
      catalog_item: @item,
      bisac_subjects: "Fiction / General",
      structured: false
    )

    assert result.skipped
    assert result.warnings.any?
  end
end
