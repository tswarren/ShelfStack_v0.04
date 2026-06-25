# frozen_string_literal: true

require "test_helper"

class SessionReturnLocationTest < ActiveSupport::TestCase
  test "sanitize accepts internal application paths" do
    assert_equal "/items", SessionReturnLocation.sanitize("/items")
    assert_equal "/items?q=test", SessionReturnLocation.sanitize("/items?q=test")
    assert_equal "/pos/transactions/1", SessionReturnLocation.sanitize("/pos/transactions/1")
  end

  test "sanitize rejects blank external and protocol-relative paths" do
    assert_nil SessionReturnLocation.sanitize(nil)
    assert_nil SessionReturnLocation.sanitize("")
    assert_nil SessionReturnLocation.sanitize("https://evil.example/phish")
    assert_nil SessionReturnLocation.sanitize("//evil.example/phish")
  end

  test "sanitize rejects auth and lock loop paths" do
    assert_nil SessionReturnLocation.sanitize("/session/unlock")
    assert_nil SessionReturnLocation.sanitize("/session/lock")
    assert_nil SessionReturnLocation.sanitize("/login")
    assert_nil SessionReturnLocation.sanitize("/password/edit")
    assert_nil SessionReturnLocation.sanitize("/pin/edit")
    assert_nil SessionReturnLocation.sanitize("/workstation_assignment/new")
  end

  test "redirect_path_for re-sanitizes stored session path" do
    session = UserSession.new(locked_return_path: "/items")
    assert_equal "/items", SessionReturnLocation.redirect_path_for(session)

    session.locked_return_path = "/session/unlock"
    assert_nil SessionReturnLocation.redirect_path_for(session)
  end
end
