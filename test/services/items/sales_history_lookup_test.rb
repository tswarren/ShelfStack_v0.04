# frozen_string_literal: true

require "test_helper"

class Items::SalesHistoryLookupTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    seed_phase5_reference_data!
    Seeds::Phase6Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1299)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @sale = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: 2,
          unit_price_cents: 1299,
          extended_price_cents: 2598,
          line_discount_cents: 0,
          transaction_discount_cents: 0
        }
      ]
    )
    complete_pos_sale!(transaction: @sale, user: @user, register_session: @register_session)
    @sale.reload
  end

  test "for_variants returns store-scoped completed sales rows" do
    rows = Items::SalesHistoryLookup.for_variants(store: @store, variant_ids: [ @variant.id ], limit: 5)

    assert_equal 1, rows.size
    assert_equal @variant.id, rows.first.variant_id
    assert_equal 2, rows.first.quantity
    assert_equal 2598, rows.first.net_sales_cents
    assert_equal @sale, rows.first.transaction
  end

  test "last_sold_at_for_variants returns latest completed sale timestamp" do
    timestamps = Items::SalesHistoryLookup.last_sold_at_for_variants(store: @store, variant_ids: [ @variant.id ])

    assert_equal @sale.completed_at, timestamps[@variant.id]
  end

  test "rollup_for_variants aggregates units and net sales by window" do
    rollups = Items::SalesHistoryLookup.rollup_for_variants(store: @store, variant_ids: [ @variant.id ], days: [ 30 ])

    rollup = rollups.fetch(@variant.id).fetch(30)
    assert_equal 2, rollup.units_sold
    assert_equal 2598, rollup.net_sales_cents
  end

  test "excludes other stores" do
    other_store = create_store!(store_number: "999")
    other_workstation = create_workstation!(store: other_store, attrs: { workstation_number: "99", workstation_code: "999-REG099" })
    create_store_tax_category_rate!(store: other_store, tax_category: @variant.sub_department.default_tax_category)
    other_session = open_register_session!(store: other_store, workstation: other_workstation, user: @user)
    other_sale = create_pos_transaction!(
      store: other_store,
      workstation: other_workstation,
      user: @user,
      lines: [
        {
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: 500,
          extended_price_cents: 500,
          line_discount_cents: 0,
          transaction_discount_cents: 0
        }
      ]
    )
    complete_pos_sale!(transaction: other_sale, user: @user, register_session: other_session)

    rows = Items::SalesHistoryLookup.for_variants(store: @store, variant_ids: [ @variant.id ], limit: 5)

    assert_equal 1, rows.size
    assert_equal @sale.id, rows.first.transaction.id
  end
end
