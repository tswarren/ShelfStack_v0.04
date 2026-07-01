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
    @product = create_product!(catalog_item: @catalog_item, variation_type: "conditional")
    add_test_product_identifier!(
      catalog_item: @catalog_item,
      identifier_type: "isbn13",
      value: "9780740747467",
      primary: true,
      actor: @user
    )
    create_product_variant!(
      product: @product,
      sub_department: @sub,
      condition: @new_condition,
      sku: "#{@product.sku}-NEW"
    )
  end

  test "links existing product without creating variant or catalog item" do
    result = Buybacks::CreateIntakeItem.call!(
      session: @session,
      actor: @user,
      line: @line,
      title: "Cher: The Memoir",
      sub_department: @sub,
      condition: @used_condition,
      identifier: "9780740747467"
    )

    assert_not result.created_new_product
    assert_equal @product.id, result.product.id
    assert_nil result.product_variant
    @line.reload
    assert_equal @product.id, @line.product_id
    assert_nil @line.created_catalog_item_id
    assert_equal "priced", @line.status
    assert @line.suggested_resale_price_cents.to_i.positive?
    assert @line.suggested_cash_offer_cents.to_i.positive?
    assert @line.suggested_trade_credit_offer_cents.to_i.positive?
    assert_equal 1, CatalogItem.where(title: "Cher: The Memoir").count
  end

  test "creates product when matching product identifier exists on inactive product" do
    catalog_only = create_catalog_item!(title: "Orphan Catalog")
    inactive_product = create_product!(
      catalog_item: catalog_only,
      active: false,
      skip_product_identifier: true
    )
    ProductIdentifierService.add_identifier!(
      product: inactive_product,
      validation_family: "gtin",
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

    assert_equal inactive_product.id, result.product.id
    assert_not result.product.active?
    assert_equal "manual", result.product.source
    assert_not result.created_new_product
    assert_nil result.product_variant
    assert_nil line.reload.created_catalog_item_id
    assert_equal "priced", line.status
  end
end
