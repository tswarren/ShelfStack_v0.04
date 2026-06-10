# frozen_string_literal: true

require "test_helper"

class AuthorizationTest < ActiveSupport::TestCase
  test "global permission applies everywhere" do
    user = create_user!
    grant_permission!(user, "setup.access")
    assert Authorization.allowed?(user: user, permission_key: "setup.access", store: nil)
  end

  test "store scoped permission only applies in matching store" do
    store1 = create_store!(store_number: "001")
    store2 = create_store!(store_number: "002")
    user = create_user!
    grant_permission!(user, "setup.stores.view", store: store1)

    assert Authorization.allowed?(user: user, permission_key: "setup.stores.view", store: store1)
    assert_not Authorization.allowed?(user: user, permission_key: "setup.stores.view", store: store2)
  end

  test "inactive user is denied" do
    user = create_user!(active: false)
    grant_permission!(user, "setup.access")
    assert_not Authorization.allowed?(user: user, permission_key: "setup.access")
  end

  test "system user is denied" do
    user = User.create!(
      user_type: "system",
      username: "system",
      first_name: "S",
      last_name: "S",
      display_name: "System",
      password: SecureRandom.hex(16),
      interactive_login_enabled: false,
      active: true
    )
    assert_not Authorization.allowed?(user: user, permission_key: "setup.access")
  end
end
