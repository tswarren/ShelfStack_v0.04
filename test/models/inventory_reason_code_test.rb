# frozen_string_literal: true

require "test_helper"

class InventoryReasonCodeTest < ActiveSupport::TestCase
  test "valid reason code saves" do
    code = InventoryReasonCode.create!(reason_key: "test_reason", name: "Test Reason", sort_order: 1)
    assert code.persisted?
  end

  test "duplicate reason_key is rejected" do
    InventoryReasonCode.create!(reason_key: "dup_key", name: "First", sort_order: 1)
    duplicate = InventoryReasonCode.new(reason_key: "dup_key", name: "Second", sort_order: 2)
    assert_not duplicate.valid?
  end

  test "duplicate name is rejected" do
    InventoryReasonCode.create!(reason_key: "key_one", name: "Shared Name", sort_order: 1)
    duplicate = InventoryReasonCode.new(reason_key: "key_two", name: "Shared Name", sort_order: 2)
    assert_not duplicate.valid?
  end
end
