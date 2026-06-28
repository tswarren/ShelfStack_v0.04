# frozen_string_literal: true

require "test_helper"

class PosTransactionDiscountModalTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "txn_discount_modal_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
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
    @gross_total = @transaction.total_cents
    @reason = DiscountReason.create!(reason_key: "txn_ws_#{SecureRandom.hex(4)}", name: "Transaction workspace test")
  end

  test "transaction edit includes transaction discount modal shell" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, 'id="pos-transaction-discount-modal"'
    assert_includes response.body, 'data-modal-dirty-guard-value="false"'
    assert_match(/id="pos-transaction-discount-modal"[\s\S]*?data-modal-dirty-guard-value="false"/, response.body)
    assert_includes response.body, "Estimated total after discount"
    assert_includes response.body, 'data-controller="pos-transaction-discount-modal-open"'
    assert_includes response.body, 'data-action="click->pos-transaction-discount-modal-open#open"'
  end

  test "route_command discount with whole number prefill percent" do
    post route_command_pos_transaction_path(@transaction), params: { input: "/discount 10" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "transaction_discount_offer", body["action"]
    assert_equal "percent", body["payload"]["discount_type"]
    assert_equal "10", body["payload"]["discount_value"]
    assert_equal "amount", body["payload"]["focus"]
  end

  test "route_command discount with decimal prefill amount" do
    post route_command_pos_transaction_path(@transaction), params: { input: "/di 5.00" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "transaction_discount_offer", body["action"]
    assert_equal "amount", body["payload"]["discount_type"]
    assert_equal "5.00", body["payload"]["discount_value"]
  end

  test "route_command discount returns transaction discount offer" do
    post route_command_pos_transaction_path(@transaction), params: { input: "/discount" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "transaction_discount_offer", body["action"]
  end

  test "apply transaction discount via modal updates totals" do
    post apply_transaction_discount_pos_transaction_path(@transaction), params: {
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream

    assert_response :success

    @transaction.reload
    assert_operator @transaction.total_cents, :<, @gross_total
    assert_equal 100, @transaction.pos_discount_applications.active_records.where(scope: "transaction").sum(:applied_discount_cents)
    assert_includes response.body, "Current transaction discount"
    assert_includes response.body, 'target="pos_transaction_discount_modal_content"'
    assert_includes response.body, format("$%.2f", @transaction.total_cents / 100.0)
  end

  test "invalid transaction discount apply reopens modal with submitted values" do
    post apply_transaction_discount_pos_transaction_path(@transaction), params: {
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="pos_transaction_discount_modal_content"'
    assert_includes response.body, 'data-controller="pos-transaction-discount-modal-open"'
    assert_includes response.body, '[&quot;discount_reason_id&quot;]'
    assert_includes response.body, 'value="1.00"'
    assert_equal 0, @transaction.reload.discount_cents
  end
end
