# frozen_string_literal: true

require "test_helper"

class PosDiscountAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "discount_auth_cashier")
    @manager = create_user!(username: "discount_auth_manager", pin: "4321")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]

    grant_permission!(@manager, "pos.authorizations.grant", store: @store)

    @reason = DiscountReason.find_or_create_by!(reason_key: "manager_adjustment") do |reason|
      reason.name = "Manager Adjustment"
      reason.sort_order = 60
      reason.requires_authorization = true
      reason.active = true
    end
    @reason.update!(requires_authorization: true, active: true)

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
  end

  test "apply line discount without authorization is rejected" do
    post apply_line_discount_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, "Authorize discount"
    assert_includes response.body, "ss-expand-row--active"
    assert_includes response.body, "ss-pos-discount-auth--invalid"
    assert_no_match(/ss-expand-row--active[^>]*hidden/, response.body)
    assert_equal 0, @line.reload.line_discount_cents
  end

  test "apply line discount without required note keeps expanded row open" do
    note_reason = DiscountReason.find_or_create_by!(reason_key: "damaged") do |reason|
      reason.name = "Damaged Item"
      reason.sort_order = 20
      reason.requires_note = true
      reason.active = true
    end
    note_reason.update!(requires_note: true, active: true)

    post apply_line_discount_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      discount_reason_id: note_reason.id,
      discount_type: "percent",
      discount_value: "10"
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, "note is required"
    assert_includes response.body, "ss-expand-row--active"
    assert_includes response.body, "ss-field--invalid"
    assert_includes response.body, 'data-pos-discount-input-invalid-fields-value="[&quot;discount_note&quot;]"'
  end

  test "apply line discount succeeds after manager authorization" do
    post pos_authorizations_path, params: {
      authorization_type: "discount_reason_approval",
      pos_transaction_id: @transaction.id,
      manager_username: @manager.username,
      manager_pin: "4321"
    }, as: :json

    assert_response :success
    authorization_id = JSON.parse(response.body)["authorization_id"]

    post apply_line_discount_pos_transaction_path(@transaction), params: {
      line_id: @line.id,
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00",
      pos_authorization_id: authorization_id
    }, as: :turbo_stream

    assert_response :success
    assert_equal 100, @line.reload.line_discount_cents
  end
end
