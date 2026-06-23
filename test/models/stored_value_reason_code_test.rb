# frozen_string_literal: true

require "test_helper"

class StoredValueReasonCodeTest < ActiveSupport::TestCase
  test "requires unique reason_key" do
    StoredValueReasonCode.create!(reason_key: "test_key", name: "Test", active: true)
    duplicate = StoredValueReasonCode.new(reason_key: "test_key", name: "Other", active: true)
    assert_not duplicate.valid?
  end
end
