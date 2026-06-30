# frozen_string_literal: true

require "test_helper"

class Buybacks::CreateIntakeItemTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @user = create_user!
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @used_condition = ProductCondition.find_by!(condition_key: "used_very_fine")
    @used_condition.update!(buyback_eligible: true) unless @used_condition.buyback_eligible?
    @new_condition = ProductCondition.find_by!(condition_key: "new")
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user)
    @line = Buybacks::AddLine.call!(
      session: @session,
      actor: @user,
      identifier_entered: "9780740747467",
      title_snapshot: "Cher: The Memoir"
    )
    @catalog_item = create_catalog_item!(title: "Cher: The Memoir")
    CatalogIdentifierService.add_identifier!(
      catalog_item: @catalog_item,
      identifier_type: "isbn13",
      value: "9780740747467",
      primary: true,
      actor: @user
    )
    @product = create_product!(catalog_item: @catalog_item, variation_type: "conditional")
    create_product_variant!(
      product: @product,
      sub_department: @sub,
      condition: @new_condition,
      sku: "#{@product.sku}-NEW"
    )
  end

  test "links existing catalog item and product without creating variant" do
    result = Buybacks::CreateIntakeItem.call!(
      session: @session,
      actor: @user,
      line: @line,
      title: "Cher: The Memoir",
      sub_department: @sub,
      condition: @used_condition,
      identifier: "9780740747467"
    )

    assert_not result.created_new_catalog
    assert_equal @catalog_item.id, result.catalog_item.id
    assert_equal @product.id, result.product.id
    assert_nil result.product_variant
    @line.reload
    assert_equal "priced", @line.status
    assert @line.suggested_resale_price_cents.to_i.positive?
    assert @line.suggested_cash_offer_cents.to_i.positive?
    assert @line.suggested_trade_credit_offer_cents.to_i.positive?
    assert_equal 1, CatalogItem.where(title: "Cher: The Memoir").count
  end

  test "creates product when legacy catalog exists without active product" do
    catalog_only = create_catalog_item!(title: "Orphan Catalog")
    CatalogIdentifierService.add_identifier!(
      catalog_item: catalog_only,
      identifier_type: "isbn13",
      value: "9780316769174",
      primary: true,
      actor: @user
    )
    line = Buybacks::AddLine.call!(
      session: @session,
      actor: @user,
      identifier_entered: "9780316769174",
      title_snapshot: "Orphan Catalog"
    )

    result = Buybacks::CreateIntakeItem.call!(
      session: @session,
      actor: @user,
      line: line,
      title: "Orphan Catalog",
      sub_department: @sub,
      condition: @used_condition,
      identifier: "9780316769174"
    )

    assert_equal catalog_only.id, result.catalog_item.id
    assert result.product.present?
    assert result.product.active?
    assert_equal "buyback_intake", result.product.source
    assert_nil result.product_variant
    assert_equal "resolved", line.reload.status
  end
end
