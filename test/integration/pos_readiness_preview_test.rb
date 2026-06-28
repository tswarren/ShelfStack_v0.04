# frozen_string_literal: true

require "test_helper"

class PosReadinessPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "readiness_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]

    post pos_transactions_path
    @transaction = PosTransaction.order(:id).last
    post add_line_pos_transaction_path(@transaction), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }
    @transaction.reload
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    @total = @transaction.total_cents
  end

  test "edit page readiness shows blockers only not passing checks" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    refute_includes response.body, "Enter tender amounts"
    refute_includes response.body, "Register open"
    refute_includes response.body, "All items active"
    refute_includes response.body, "ss-pos-readiness-list"
    assert_match(/id="pos_completion_readiness" class="js-pos-readiness-host" hidden/, response.body)
  end

  test "settlement modal readiness host hidden before tender entry" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_match(/id="pos_settlement_readiness" class="js-pos-readiness-host" hidden/, response.body)
  end

  test "readiness preview marks matching cash tender as complete ready" do
    post readiness_preview_pos_transaction_path(@transaction), params: {
      tenders: [
        { amount_dollars: format("%.2f", @total / 100.0), tender_type: "cash" },
        { amount_dollars: "0", tender_type: "card" },
        { amount_dollars: "0", tender_type: "check" }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    assert body["complete_ready"], body.inspect
    assert body["tender_ready"]
    tender_check = body["checks"].find { |check| check["key"] == "tenders" }
    assert_equal "ok", tender_check["status"]
    assert_equal "Tendered in full", tender_check["message"]
    assert_equal false, body["readiness_visible"]
    refute_includes body["panel_html"], "Register open"
    refute_includes body["panel_html"], "Ready to complete"
  end

  test "readiness preview accepts form-style tender array ordering" do
    post readiness_preview_pos_transaction_path(@transaction),
         params: {
           "tenders" => [
             { "amount_dollars" => format("%.2f", @total / 100.0), "tender_type" => "cash" },
             { "amount_dollars" => "0", "tender_type" => "card" },
             { "amount_dollars" => "0", "tender_type" => "check" }
           ]
         },
         as: :json

    assert_response :success
    assert JSON.parse(response.body)["complete_ready"]
  end

  test "readiness preview marks under-tendered sale as not complete ready" do
    partial = format("%.2f", @total / 200.0)

    post readiness_preview_pos_transaction_path(@transaction), params: {
      tenders: [
        { amount_dollars: partial, tender_type: "cash" },
        { amount_dollars: "0", tender_type: "card" },
        { amount_dollars: "0", tender_type: "check" }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    refute body["complete_ready"], body.inspect
    refute body["tender_ready"]
    refute body["structural_blocked"]
    assert_equal true, body["readiness_visible"]
    tender_check = body["checks"].find { |check| check["key"] == "tenders" }
    assert_equal "block", tender_check["status"]
    assert_includes body["panel_html"], tender_check["message"]
  end

  test "readiness preview does not require cash refund auth on sale over threshold" do
    expensive = create_product_variant!(
      sub_department: @variant.sub_department,
      sku: "READINESS-EXPENSIVE",
      selling_price_cents: 6000
    )
    receive_inventory!(store: @store, vendor: create_vendor!, variant: expensive, user: @cashier, quantity: 5)

    post add_line_pos_transaction_path(@transaction), params: {
      product_variant_id: expensive.id,
      quantity: 1,
      entry_action: "sale"
    }
    @transaction.reload
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    total = @transaction.total_cents

    post readiness_preview_pos_transaction_path(@transaction), params: {
      tenders: [
        { amount_dollars: format("%.2f", total / 100.0), tender_type: "cash" },
        { amount_dollars: "0", tender_type: "card" },
        { amount_dollars: "0", tender_type: "check" }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    assert body["complete_ready"], body.inspect
    refute body["checks"].any? { |check| check["key"] == "cash_refund_auth" && check["status"] == "block" }
  end
end
