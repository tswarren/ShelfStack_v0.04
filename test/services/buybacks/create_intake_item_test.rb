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

  test "adds used variant to existing catalog item instead of duplicating identifier" do
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
    assert_equal @used_condition.id, result.product_variant.condition_id
    assert_equal "buyback_intake", result.product_variant.source
    assert_equal 1, CatalogItem.where(title: "Cher: The Memoir").count
  end
end
