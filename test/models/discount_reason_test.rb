# frozen_string_literal: true

require "test_helper"

class DiscountReasonTest < ActiveSupport::TestCase
  test "requires reason_key and name" do
    reason = DiscountReason.new

    assert_not reason.valid?
    assert_includes reason.errors[:reason_key], "can't be blank"
    assert_includes reason.errors[:name], "can't be blank"
  end

  test "normalizes reason_key to lowercase" do
    reason = DiscountReason.create!(reason_key: "PROMO_TEST", name: "Promo Test #{SecureRandom.hex(4)}")

    assert_equal "promo_test", reason.reason_key
  end

  test "active_records scope returns only active reasons" do
    active = DiscountReason.create!(reason_key: "active_test", name: "Active #{SecureRandom.hex(4)}", active: true)
    inactive = DiscountReason.create!(reason_key: "inactive_test", name: "Inactive #{SecureRandom.hex(4)}", active: false)

    assert_includes DiscountReason.active_records, active
    assert_not_includes DiscountReason.active_records, inactive
  end

  test "inactivate and reactivate" do
    reason = DiscountReason.create!(reason_key: "toggle_test", name: "Toggle #{SecureRandom.hex(4)}")

    reason.inactivate!
    assert_not reason.reload.active?

    reason.reactivate!
    assert reason.reload.active?
  end
end
