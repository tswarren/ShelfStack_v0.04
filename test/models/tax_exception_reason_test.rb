# frozen_string_literal: true

require "test_helper"

class TaxExceptionReasonTest < ActiveSupport::TestCase
  test "requires key name and exception type" do
    reason = TaxExceptionReason.new

    assert_not reason.valid?
    assert_includes reason.errors[:reason_key], "can't be blank"
    assert_includes reason.errors[:name], "can't be blank"
    assert_includes reason.errors[:exception_type], "can't be blank"
  end

  test "normalizes reason key" do
    reason = TaxExceptionReason.create!(
      reason_key: " Resale ",
      name: "Resale Certificate",
      exception_type: "exemption"
    )

    assert_equal "resale", reason.reason_key
  end

  test "for_exemption scope includes exemption and both" do
    exemption = TaxExceptionReason.create!(reason_key: "exempt_only", name: "Exempt", exception_type: "exemption")
    both = TaxExceptionReason.create!(reason_key: "both_types", name: "Both", exception_type: "both")
    TaxExceptionReason.create!(reason_key: "override_only", name: "Override", exception_type: "rate_override")

    ids = TaxExceptionReason.for_exemption.pluck(:id)

    assert_includes ids, exemption.id
    assert_includes ids, both.id
    assert_equal 2, ids.size
  end
end
