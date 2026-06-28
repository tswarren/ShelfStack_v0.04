# frozen_string_literal: true

require "test_helper"

class PosCartExpandedRowTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "cart_expanded_row_cashier")
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
    @line = @transaction.pos_transaction_lines.first
  end

  test "cart renders 10-A expanded row markup for line edit" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_select ".ss-expand-row[data-pos-cart-line-target='editRow'][data-line-id='#{@line.id}'][hidden]"
    assert_select "#pos_line_edit_#{@line.id}.ss-row-detail"
    assert_select ".ss-row-detail__header .ss-pos-line-edit__title", text: /Edit line ·/
    assert_select ".ss-row-detail__footer button[data-action='pos-cart-line#cancel']"
    assert_select "button[data-action='pos-cart-line#edit'][aria-expanded='false'][aria-controls='pos_line_edit_#{@line.id}']"
  end

  test "update line via turbo stream re-renders collapsed expanded row" do
    patch update_line_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      quantity: 2
    }, as: :turbo_stream

    assert_response :success
    assert_equal 2, @line.reload.quantity
    assert_match(/ss-expand-row/, response.body)
    assert_match(/ss-row-detail/, response.body)
    assert_match(/pos-workspace-focus/, response.body)
  end
end
