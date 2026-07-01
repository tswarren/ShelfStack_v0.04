# frozen_string_literal: true

require "test_helper"

class ShelfstackV0046VerifyTest < ActiveSupport::TestCase
  test "report includes strict cutover checks" do
    result = Shelfstack::V0046Verify.report(strict: true)

    expected_keys = %i[
      tables_present
      demand_number_format
      demand_services_avoid_legacy_writes
      demand_services_avoid_inventory_post
      used_wanted_valid
      manual_tbo_vendor_orderable
      buyer_replenishment_vendor_orderable
      manual_tbo_isolated
    ]

    assert_equal expected_keys.sort, result[:checks].keys.sort
    assert result[:checks][:demand_services_avoid_legacy_writes]
    assert result[:checks][:demand_services_avoid_inventory_post]
  end
end
