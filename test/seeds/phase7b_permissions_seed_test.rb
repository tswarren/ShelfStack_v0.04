# frozen_string_literal: true

require "test_helper"

class Phase7bPermissionsSeedTest < ActiveSupport::TestCase
  test "permissions seed is idempotent" do
    Seeds::Phase7bPermissions.seed!
    count = Permission.where("permission_key LIKE ?", "stored_value.%").count
    Seeds::Phase7bPermissions.seed!
    assert_equal count, Permission.where("permission_key LIKE ?", "stored_value.%").count
  end
end
