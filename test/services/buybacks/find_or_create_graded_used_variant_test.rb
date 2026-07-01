# frozen_string_literal: true

require "test_helper"

class Buybacks::FindOrCreateGradedUsedVariantTest < ActiveSupport::TestCase
  include Phase7cTestHelper

  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @product = create_product!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @session = create_buyback_session!(store: @store, customer: create_buyback_customer!, actor: @user, workstation: @workstation)
  end

  test "creates used variant with 211 sku and orderable false" do
    variant = Buybacks::FindOrCreateGradedUsedVariant.call!(
      product: @product,
      condition: @condition,
      sub_department: @sub,
      resale_price_cents: 1200,
      session: @session,
      actor: @user
    )

    assert_match(/\A211[0-9]{10}\z/, variant.sku)
    assert_not variant.orderable?
    assert_equal "buyback_intake", variant.source
    assert_equal @condition, variant.condition
  end

  test "reuses existing used variant for same condition and subdepartment" do
    existing = create_product_variant!(
      product: @product,
      condition: @condition,
      sub_department: @sub,
      orderable: false
    )

    variant = Buybacks::FindOrCreateGradedUsedVariant.call!(
      product: @product,
      condition: @condition,
      sub_department: @sub,
      resale_price_cents: 1200,
      session: @session,
      actor: @user
    )

    assert_equal existing.id, variant.id
  end
end
