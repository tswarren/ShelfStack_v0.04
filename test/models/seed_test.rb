# frozen_string_literal: true

require "test_helper"

class SeedTest < ActiveSupport::TestCase
  test "seeds are idempotent" do
    original_stdout = $stdout
    $stdout = StringIO.new

    load Rails.root.join("db/seeds.rb")
    user_count = User.count
    permission_count = Permission.count
    store_count = Store.count

    load Rails.root.join("db/seeds.rb")

    assert_equal user_count, User.count
    assert_equal permission_count, Permission.count
    assert_equal store_count, Store.count
  ensure
    $stdout = original_stdout
  end
end
