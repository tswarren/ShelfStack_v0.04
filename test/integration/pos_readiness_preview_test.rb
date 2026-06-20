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
    assert_includes body["panel_html"], "Ready to complete"
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
    post readiness_preview_pos_transaction_path(@transaction), params: {
      tenders: [
        { amount_dollars: "1.00", tender_type: "cash" },
        { amount_dollars: "0", tender_type: "card" },
        { amount_dollars: "0", tender_type: "check" }
      ]
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    refute body["complete_ready"], body.inspect
    refute body["tender_ready"]
    refute body["structural_blocked"]
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
