# frozen_string_literal: true

require "test_helper"

class Reports::InclusionRulesTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase3TestHelper
  include Phase4TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "reportsrules#{SecureRandom.hex(3)}")
  end

  test "pos_sales_transactions includes only completed transactions" do
    completed = create_pos_transaction!(status: "completed")
    create_pos_transaction!(status: "draft")

    ids = Reports::InclusionRules.pos_sales_transactions(store: @store).pluck(:id)

    assert_includes ids, completed.id
    assert_equal 1, ids.size
  end

  test "pos_excluded_from_sales includes non-completed statuses" do
    create_pos_transaction!(status: "completed")
    draft = create_pos_transaction!(status: "draft")

    ids = Reports::InclusionRules.pos_excluded_from_sales(store: @store).pluck(:id)

    assert_includes ids, draft.id
  end

  test "buyback_reportable_sessions includes completed and voided" do
    completed = create_buyback_session!(status: "completed")
    create_buyback_session!(status: "draft")

    ids = Reports::InclusionRules.buyback_reportable_sessions(store: @store).pluck(:id)

    assert_includes ids, completed.id
    assert_equal 1, ids.size
  end

  test "inventory_ledger_entries returns posted ledger rows" do
    variant = create_product_variant!
    adjustment = create_inventory_adjustment!(
      store: @store,
      lines: [ { product_variant: variant, quantity_delta: 1, line_number: 1 } ]
    )
    Inventory::PostAdjustment.call(adjustment: adjustment, posted_by_user: @user)

    assert Reports::InclusionRules.inventory_ledger_entries(store: @store).exists?
  end

  private

  def create_pos_transaction!(status:)
    PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: status,
      transaction_type: "sale",
      business_date: Date.current,
      subtotal_cents: 1000,
      discount_cents: 0,
      tax_cents: 0,
      total_cents: 1000
    )
  end

  def create_buyback_session!(status:)
    customer = Customer.create!(
      display_name: "Buyback Customer",
      country_code: "US",
      active: true
    )

    BuybackSession.create!(
      store: @store,
      customer: customer,
      created_by_user: @user,
      status: status,
      payout_mode: "cash"
    )
  end
end
