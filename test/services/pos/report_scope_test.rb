# frozen_string_literal: true

require "test_helper"

class Pos::ReportScopeTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @other_store = create_store!(store_number: "002", name: "Other Store")
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @session = open_register_session!(store: @store, workstation: @workstation, user: @user)
  end

  test "from_params returns nil for invalid business date" do
    assert_nil Pos::ReportScope.from_params(store: @store, params: { business_date: "not-a-date" })
  end

  test "from_params returns nil when date range is reversed" do
    assert_nil Pos::ReportScope.from_params(
      store: @store,
      params: { start_date: "2026-06-10", end_date: "2026-06-01" }
    )
  end

  test "from_params respects filter_type register_session" do
    scope = Pos::ReportScope.from_params(
      store: @store,
      params: {
        filter_type: "register_session",
        register_session_id: @session.id,
        business_date: Date.current.to_s,
        start_date: 30.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }
    )

    assert_equal :register_session, scope.type
    assert_equal @session.id, scope.register_session.id
  end

  test "from_params respects filter_type business_date" do
    scope = Pos::ReportScope.from_params(
      store: @store,
      params: {
        filter_type: "business_date",
        business_date: @session.business_date.to_s,
        start_date: 30.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }
    )

    assert_equal :business_date, scope.type
    assert_equal @session.business_date, scope.business_date
  end

  test "from_params respects filter_type date_range over business_date" do
    start_date = Date.new(2026, 6, 1)
    end_date = Date.new(2026, 6, 5)

    scope = Pos::ReportScope.from_params(
      store: @store,
      params: {
        filter_type: "date_range",
        start_date: start_date.to_s,
        end_date: end_date.to_s,
        business_date: Date.new(2026, 6, 15).to_s
      }
    )

    assert_equal :date_range, scope.type
    assert_equal start_date, scope.start_date
    assert_equal end_date, scope.end_date
  end

  test "from_params returns nil when filter_type date_range lacks dates" do
    assert_nil Pos::ReportScope.from_params(
      store: @store,
      params: { filter_type: "date_range", business_date: Date.current.to_s }
    )
  end

  test "from_params scopes register session to store" do
    other_workstation = create_workstation!(
      store: @other_store,
      attrs: { workstation_number: "001", workstation_code: "002-REG001" }
    )
    other_session = open_register_session!(
      store: @other_store,
      workstation: other_workstation,
      user: @user
    )

    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { register_session_id: other_session.id }
    )

    assert_nil scope
  end

  test "business date scope filters completed transactions" do
    variant = create_product_variant!(selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: variant, user: @user, quantity: 2)

    transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000
      } ]
    )
    complete_pos_sale!(transaction: transaction, user: @user, register_session: @session)

    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { business_date: @session.business_date.to_s }
    )

    assert_equal :business_date, scope.type
    assert_includes scope.transactions.pluck(:id), transaction.id
  end
end
