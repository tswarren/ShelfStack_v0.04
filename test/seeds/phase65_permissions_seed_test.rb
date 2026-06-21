# frozen_string_literal: true

require "test_helper"

class Phase65PermissionsSeedTest < ActiveSupport::TestCase
  test "phase 65 permissions seed is idempotent" do
    Seeds::Phase65Permissions.seed!

    %w[
      items.external_lookup.access
      items.external_lookup.search
      items.external_lookup.import
      items.external_lookup.link_existing
      items.external_lookup.update_existing
      items.external_lookup.view_raw_payload
      items.external_lookup.configure
    ].each do |key|
      assert Permission.active_records.exists?(permission_key: key), "expected permission #{key}"
    end

    assert_no_difference -> { Permission.count } do
      Seeds::Phase65Permissions.seed!
    end
  end
end
