# frozen_string_literal: true

require "test_helper"

class Reports::SalesControllerTest < ActionDispatch::IntegrationTest
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "repsaleslist#{SecureRandom.hex(3)}")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: @user.username, password: "Password123!" }
    grant_all_phase6_permissions!(@user, store: @store)

    context = setup_pos_workstation!(
      user: @user,
      store: @store,
      workstation: @workstation,
      login: false,
      grant_permissions: false
    )
    @variant = context[:variant]
    @register_session = context[:register_session]

    @sale = create_completed_pos_sale!(
      user: @user,
      register_session: @register_session,
      variant: @variant,
      store: @store,
      workstation: @workstation
    )

    @return_tx = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ {
        product_variant: @variant,
        quantity: -1,
        unit_price_cents: @variant.selling_price_cents,
        extended_price_cents: -@variant.selling_price_cents,
        return_disposition: "return_to_stock",
        source_transaction_line: @sale.pos_transaction_lines.first
      } ]
    )
    Pos::RecalculateTransaction.call!(@return_tx, business_date: @register_session.business_date)
    create_pos_tender!(@return_tx, tender_type: "cash", amount_cents: @return_tx.total_cents)
    Pos::CompleteTransaction.call!(
      transaction: @return_tx.reload,
      completed_by_user: @user,
      register_session: @register_session,
      confirmed_inactive: true
    )
    @return_tx.reload
  end

  test "sales list excludes returns and exchanges" do
    get reports_sales_path

    assert_response :success
    assert_includes response.body, @sale.transaction_number
    assert_not_includes response.body, @return_tx.transaction_number
  end
end
