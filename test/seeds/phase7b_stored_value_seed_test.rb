# frozen_string_literal: true

require "test_helper"

class Phase7bStoredValueSeedTest < ActiveSupport::TestCase
  test "reason codes seed is idempotent" do
    Seeds::Phase7bStoredValue.seed!
    count = StoredValueReasonCode.count
    Seeds::Phase7bStoredValue.seed!
    assert_equal count, StoredValueReasonCode.count
    assert StoredValueReasonCode.exists?(reason_key: "manual_issue")
  end
end
