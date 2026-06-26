# frozen_string_literal: true

require "test_helper"

class Reports::ProcurementPathResolverTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase3TestHelper

  setup do
    @store = create_store!
    @variant = create_product_variant!
    @product = @variant.product
  end

  test "returns not_applicable for gift card sale line type" do
    assert_equal "not_applicable",
                 Reports::ProcurementPathResolver.call(product_variant: @variant, line_type: "gift_card_sale")
  end

  test "returns not_applicable for service product" do
    @product.update!(product_type: "service")

    assert_equal "not_applicable", Reports::ProcurementPathResolver.call(product_variant: @variant)
  end

  test "returns buyback for buyback-created variant" do
    customer = Customer.create!(display_name: "Buyback Seller", country_code: "US", active: true)
    session = BuybackSession.create!(
      store: @store,
      customer: customer,
      created_by_user: create_user!(username: "bbuser#{SecureRandom.hex(3)}"),
      status: "draft",
      payout_mode: "cash"
    )
    @variant.update!(created_from_buyback_session: session)

    assert_equal "buyback", Reports::ProcurementPathResolver.call(product_variant: @variant.reload)
  end

  test "returns buyback_donation for donated buyback line" do
    line = BuybackLine.new(outcome: "donated_by_customer")

    assert_equal "buyback_donation",
                 Reports::ProcurementPathResolver.call(product_variant: @variant, buyback_line: line)
  end

  test "returns vendor_order when variant is orderable" do
    @variant.update!(orderable: true)

    assert_equal "vendor_order", Reports::ProcurementPathResolver.call(product_variant: @variant)
  end

  test "returns manual_stock for inventory variant without vendor signals" do
    @variant.update!(orderable: false, preferred_vendor_id: nil, inventory_behavior: "standard_physical")

    assert_equal "manual_stock", Reports::ProcurementPathResolver.call(product_variant: @variant)
  end
end
