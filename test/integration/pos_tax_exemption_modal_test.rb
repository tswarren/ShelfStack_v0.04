# frozen_string_literal: true

require "test_helper"
require_relative "../../db/seeds/phase852_permissions"

class PosTaxExemptionModalTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "tax_exemption_modal_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, opening_cash_cents: 10_000)
    @store = @ctx[:store]
    @variant = @ctx[:variant]
    @register_session = @ctx[:register_session]
    Seeds::Phase852Permissions.seed!
    grant_permission!(@cashier, "pos.tax_exemptions.apply", store: @store)

    @reason = TaxExceptionReason.create!(
      reason_key: "resale_modal_#{SecureRandom.hex(4)}",
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

  test "transaction edit includes tax exemption modal shell" do
    get edit_pos_transaction_path(@transaction)

    assert_response :success
    assert_includes response.body, 'id="pos-tax-exemption-modal"'
    assert_includes response.body, 'id="pos_tax_exemption_modal_content"'
    assert_match(/id="pos-tax-exemption-modal"[\s\S]*?data-modal-dirty-guard-value="false"/, response.body)
  end

  test "invalid tax exemption apply reopens modal with submitted values" do
    post apply_tax_exemption_pos_transaction_path(@transaction), params: {
      certificate_number: "CERT-123"
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, 'target="pos_tax_exemption_modal_content"'
    assert_includes response.body, 'data-controller="pos-tax-exemption-modal-open"'
    assert_includes response.body, "[&quot;tax_exception_reason_id&quot;]"
    assert_includes response.body, 'value="CERT-123"'
    assert_includes response.body, "ss-pos-tax-exemption-form__error"
    assert_no_match(/ss-pos-alert ss-pos-alert--error/, response.body)
  end

  test "apply tax exemption with required certificate succeeds" do
    post apply_tax_exemption_pos_transaction_path(@transaction), params: {
      tax_exception_reason_id: @reason.id,
      certificate_number: "CERT-999"
    }, as: :turbo_stream

    assert_response :success
    assert_equal @reason.id, @transaction.reload.active_tax_exemption.tax_exception_reason_id
  end
end
