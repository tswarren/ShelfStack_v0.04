# frozen_string_literal: true

require "test_helper"

class ShelfstackV0049VerifyTest < ActiveSupport::TestCase
  test "report includes slice A checks" do
    result = Shelfstack::V0049Verify.report(strict: false)

    assert_includes result[:checks].keys, :po_line_vendor_columns_present
    assert_includes result[:checks].keys, :core_services_present
    assert_includes result[:checks].keys, :inbound_within_open_supply
  end
end
