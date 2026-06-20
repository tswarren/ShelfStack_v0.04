# frozen_string_literal: true

require "test_helper"

class PosReadinessPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "readiness_cashier")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 10_000)

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
end
