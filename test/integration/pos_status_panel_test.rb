# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/phase85_permissions"
require_relative "../../db/seeds/phase852_permissions"

class PosStatusPanelTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "pos_status_panel_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]
    Seeds::Phase85Permissions.seed!
    Seeds::Phase852Permissions.seed!
    grant_permission!(@cashier, "pos.discounts.void", store: @store)
    grant_permission!(@cashier, "pos.tax_exemptions.apply", store: @store)
    grant_permission!(@cashier, "pos.tax_exemptions.void", store: @store)

    @reason = DiscountReason.create!(
      reason_key: "status_panel_#{SecureRandom.hex(4)}",
      name: "Status Panel Discount"
    )
    @tax_reason = TaxExceptionReason.create!(
      reason_key: "status_panel_tax_#{SecureRandom.hex(4)}",
      name: "Resale Certificate",
      exception_type: "exemption",
      requires_certificate: true
    )

    post pos_transactions_path
    @transaction = PosTransaction.order(:id).last
    post add_line_pos_transaction_path(@transaction), params: {
      product_variant_id: @variant.id,
      quantity: 1,
      entry_action: "sale"
    }
    @transaction.reload
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
  end

  test "edit page renders status panel instead of adjustments details" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_select "#pos_status_panel"
    assert_select ".ss-pos-status-panel"
    assert_select "#pos_customer_status"
    assert_select ".ss-pos-status-panel__title", text: "Customer"
    assert_select "details.ss-pos-adjustments", count: 0
    assert_select "button", text: "Add discount"
    assert_select "button", text: "Link customer"
    assert_select "button[data-action=?]", "pos-command-bar#showTaxExemptionModal", text: "Apply exemption"
  end

  test "transaction discount appears in status panel after apply" do
    post apply_transaction_discount_pos_transaction_path(@transaction), params: {
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Status Panel Discount"
    assert_includes response.body, 'target="pos_status_panel"'
  end

  test "void discount updates status panel" do
    post apply_transaction_discount_pos_transaction_path(@transaction), params: {
      discount_reason_id: @reason.id,
      discount_type: "amount",
      discount_value: "1.00"
    }, as: :turbo_stream
    application = @transaction.reload.pos_discount_applications.active_records.first

    delete void_discount_application_pos_transaction_path(@transaction, application_id: application.id),
           as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="pos_status_panel"'
    assert_equal 0, @transaction.reload.pos_discount_applications.active_records.where(scope: "transaction").count
  end

  test "tax exemption apply updates status panel via modal flow" do
    post apply_tax_exemption_pos_transaction_path(@transaction), params: {
      tax_exception_reason_id: @tax_reason.id,
      certificate_number: "CERT-123"
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Resale Certificate"
    assert_includes response.body, 'target="pos_status_panel"'
  end
end
