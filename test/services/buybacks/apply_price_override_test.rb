# frozen_string_literal: true

require "test_helper"

class Buybacks::ApplyPriceOverrideTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(
      sub_department: @sub,
      condition: @condition,
      selling_price_cents: 2000,
      product: create_product!(list_price_cents: 3000)
    )
    @session = create_buyback_session!(store: @store, customer: create_buyback_customer!, actor: @user)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Override Base")
    @line.update!(product: @variant.product, catalog_item: @variant.product.catalog_item, sub_department: @sub, product_condition: @condition)
  end

  test "recalculates offers from overridden resale rather than list price" do
    Buybacks::ApplyPriceOverride.call!(
      line: @line,
      actor: @user,
      resale_price_cents: 1000,
      override_reason: "Manual resale"
    )

    @line.reload
    assert_equal 1000, @line.proposed_resale_price_cents
    assert @line.proposed_cash_offer_cents.to_i.positive?
    assert @line.proposed_cash_offer_cents.to_i < 1000
    assert_equal "manual_resale_price", @line.base_price_source
  end
end
