# frozen_string_literal: true

require "test_helper"

class Buybacks::PricingFieldSyncTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @user = create_user!
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Pricing Book")
    @line.update!(
      product: @variant.product,
      catalog_item: @variant.product.catalog_item,
      product_variant: @variant,
      product_condition: @condition,
      sub_department: @sub,
      list_price_cents: @variant.product.list_price_cents,
      status: "resolved"
    )
  end

  test "refresh persists suggested and proposed values from pricing rules" do
    pricing = Buybacks::PricingFieldSync.refresh!(line: @line.reload)

    assert pricing.resale_price_cents.positive?
    assert pricing.cash_offer_cents.positive?
    assert pricing.trade_credit_offer_cents.positive?
    @line.reload
    assert_equal pricing.resale_price_cents, @line.suggested_resale_price_cents
    assert_equal pricing.cash_offer_cents, @line.suggested_cash_offer_cents
    assert_equal pricing.trade_credit_offer_cents, @line.suggested_trade_credit_offer_cents
    assert_equal pricing.resale_price_cents, @line.proposed_resale_price_cents
    assert_equal "priced", @line.status
  end

  test "refresh returns nil when condition or subdepartment is missing" do
    @line.update!(product_condition: nil)

    assert_nil Buybacks::PricingFieldSync.refresh!(line: @line.reload)
  end
end
