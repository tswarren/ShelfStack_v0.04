# frozen_string_literal: true

require "test_helper"

class Pos::VoidTaxExceptionTest < ActiveSupport::TestCase
  include Phase6TestHelper

  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @variant = create_product_variant!(selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 600)
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category, store_tax_rate: @rate)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [ { product_variant: @variant, quantity: 1, unit_price_cents: 1000, line_type: "variant" } ]
    )
    @reason = TaxExceptionReason.create!(
      reason_key: "resale",
      name: "Resale Certificate",
      exception_type: "exemption",
      requires_certificate: true
    )
    @exemption = Pos::TaxExceptionApplicationService.call!(
      transaction: @transaction,
      scope: "transaction",
      tax_exception_reason: @reason,
      certificate_number: "MI-123456",
      actor: @user
    )
  end

  test "void restores tax and creates audit event" do
    assert_difference -> { AuditEvent.where(event_name: "pos.tax_exemption.voided").count }, 1 do
      Pos::VoidTaxException.call!(record: @exemption, actor: @user)
    end

    line = @transaction.pos_transaction_lines.first.reload

    assert_equal 60, line.tax_cents
    assert_equal "normal", line.applied_tax_source
    assert @exemption.reload.voided?
  end
end
