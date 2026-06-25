# frozen_string_literal: true

require "test_helper"

class PosLineDiscountWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "line_discount_cashier")
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
    @line = @transaction.pos_transaction_lines.first
    @gross_total = @transaction.total_cents
    @reason = DiscountReason.create!(reason_key: "line_ws_#{SecureRandom.hex(4)}", name: "Line workspace test")
  end

  test "apply line discount updates totals and settlement via turbo stream" do
    post apply_line_discount_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream

    assert_response :success

    @transaction.reload
    @line.reload

    assert_equal 100, @line.line_discount_cents
    assert_operator @transaction.total_cents, :<, @gross_total
    assert_includes response.body, "Item discounts"
    assert_includes response.body, format("$%.2f", @transaction.total_cents / 100.0)
    assert_includes response.body, 'data-total-cents="' + @transaction.total_cents.to_s + '"'
    assert_match(/pos-settlement-open-btn/, response.body)
  end

  test "update line requires pos.lines.update permission" do
    delete logout_path

    limited_user = create_user!(username: "line_update_denied")
    grant_permission!(limited_user, "pos.access", store: @store)
    grant_permission!(limited_user, "pos.transactions.create", store: @store)
    grant_permission!(limited_user, "pos.transactions.update", store: @store)
    grant_permission!(limited_user, "pos.lines.add", store: @store)
    grant_permission!(limited_user, "pos.discounts.line.apply", store: @store)

    login_user!(limited_user, workstation: @ctx[:workstation])

    patch update_line_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      quantity: 2
    }, as: :turbo_stream

    assert_redirected_to pos_root_path
    assert_equal "You are not authorized to perform that action.", flash[:alert]
    assert_equal 1, @line.reload.quantity
  end
end
