# frozen_string_literal: true

require "test_helper"

class PosLineTaxOverrideTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    @reason = TaxExceptionReason.create!(
      reason_key: "wrong_tax_category",
      name: "Wrong Tax Category",
      exception_type: "rate_override",
      requires_note: true
    )
    @category = TaxCategory.first || create_tax_category!
    @rate = create_store_tax_rate!(store: @store, tax_rate_bps: 0, name: "Non-Taxable Rate", short_name: "NT", tax_identifier: "N")
    create_store_tax_category_rate!(store: @store, tax_category: @category, store_tax_rate: @rate)
  end

  test "requires rate-override-capable reason" do
    exemption_reason = TaxExceptionReason.create!(
      reason_key: "exempt_only",
      name: "Exempt",
      exception_type: "exemption"
    )

    override = PosLineTaxOverride.new(
      pos_transaction: @transaction,
      pos_transaction_line: @transaction.pos_transaction_lines.first,
      tax_exception_reason: exemption_reason,
      override_tax_category: @category,
      override_store_tax_rate: @rate,
      override_tax_rate_bps: 0,
      overridden_by_user: @user,
      overridden_at: Time.current
    )

    assert_not override.valid?
  end
end
