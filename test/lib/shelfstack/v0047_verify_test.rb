# frozen_string_literal: true

require "test_helper"

class ShelfstackV0047VerifyTest < ActiveSupport::TestCase
  test "report passes on empty database" do
    result = Shelfstack::V0047Verify.report(strict: true)

    assert_equal "PASS", result[:status]
    assert result[:checks][:tables_present]
  end
end
