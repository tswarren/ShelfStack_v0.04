# frozen_string_literal: true

require "test_helper"

class Pos::CompleteTransactionCogsTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(selling_price_cents: 1800)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 4, unit_cost_cents: 900)
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "completion snapshots tracking and cogs before inventory post" do
    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1800, extended_price_cents: 1800 } ]
    )

    complete_pos_sale!(transaction: transaction, user: @user, register_session: @session)
    line = transaction.pos_transaction_lines.first.reload

    assert_equal "inventory", line.inventory_tracking_snapshot
    assert_equal 900, line.unit_cogs_cents
    assert_equal 900, line.total_cogs_cents
    assert_equal "moving_average", line.cogs_source
    assert_not line.cogs_estimated?
  end
end
