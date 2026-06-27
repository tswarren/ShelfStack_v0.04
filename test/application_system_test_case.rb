# frozen_string_literal: true

require "test_helper"
require_relative "support/system_test_driver"
require_relative "support/system_test_database"

SystemTestDriver.register!

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.use_transactional_tests = false

  driven_by :shelfstack_headless_chrome, screen_size: [ 1400, 1400 ]

  include Phase1TestHelper
  include Phase2TestHelper
  include Phase3TestHelper
  include Phase7aTestHelper

  setup do
    SystemTestDatabase.reset!
    seed_minimal_permissions!
  end

  def send_escape
    page.driver.browser.action.send_keys(:escape).perform
  end

  def system_login!(user, workstation:, password: "Password123!")
    raw = TokenDigest.generate
    WorkstationAssignment.active_records.where(workstation: workstation).find_each(&:revoke!)
    WorkstationAssignment.create!(
      workstation: workstation,
      assignment_token_digest: TokenDigest.digest(raw),
      assigned_at: Time.current
    )

    visit login_path
    page.driver.browser.manage.add_cookie(
      name: ShelfStack::WORKSTATION_COOKIE_NAME,
      value: raw,
      path: "/"
    )
    visit login_path
    fill_in "username", with: user.username
    fill_in "password", with: password
    click_button "Log In"
    assert_text "Dashboard", wait: 5
  end
end
