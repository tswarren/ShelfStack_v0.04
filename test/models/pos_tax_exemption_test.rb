# frozen_string_literal: true

require "test_helper"

class PosTaxExemptionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @user = create_user!
    @workstation = create_workstation!(store: @store)
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
    @reason = TaxExceptionReason.create!(
      reason_key: "nonprofit",
      name: "Nonprofit Exemption",
      exception_type: "exemption"
    )
  end

  test "requires exemption-capable reason" do
    override_reason = TaxExceptionReason.create!(
      reason_key: "wrong_category",
      name: "Wrong Tax Category",
      exception_type: "rate_override"
    )

    exemption = PosTaxExemption.new(
      pos_transaction: @transaction,
      tax_exception_reason: override_reason,
      exempted_by_user: @user,
      exempted_at: Time.current
    )

    assert_not exemption.valid?
    assert_includes exemption.errors[:tax_exception_reason], "must allow exemption"
  end
end
