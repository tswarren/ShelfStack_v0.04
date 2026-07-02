# frozen_string_literal: true

require "test_helper"

class ShelfstackV0047VerifyTest < ActiveSupport::TestCase
  setup do
    User.find_or_create_by!(username: ShelfStack::SYSTEM_USERNAME) do |user|
      user.user_type = "system"
      user.first_name = "System"
      user.last_name = "User"
      user.display_name = "System"
      user.interactive_login_enabled = false
      user.active = true
      user.password = "Password123!"
    end
  end

  test "report passes on empty database" do
    result = Shelfstack::V0047Verify.report(strict: true)

    assert_equal "PASS", result[:status]
    assert result[:checks][:tables_present]
    assert result[:checks][:system_user_present]
  end
end
