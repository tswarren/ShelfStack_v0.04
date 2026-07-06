# frozen_string_literal: true

require "application_system_test_case"

class AppShellContractTest < ApplicationSystemTestCase
  include Phase4TestHelper
  include Phase5TestHelper
  include Phase6TestHelper
  include PosSystemTestHelper

  test "non-POS and POS layouts expose the same shell contract" do
    setup_pos_system_sale!
    @cashier.update!(appearance_view_mode: "accessible", appearance_color_mode: "light")

    visit root_path

    assert_selector "body.ss-app-body[data-ss-typeface='lexend'][data-ss-density='comfortable'][data-ss-color-mode='light']"
    assert_selector "a.ss-skip-link[href='#main_content']", visible: :all
    assert_selector "header.ss-header[role='banner']"
    assert_selector "nav.ss-nav[aria-label='Primary navigation']"
    assert_selector "main#main_content.ss-main"

    visit edit_pos_transaction_path(@transaction)

    assert_selector "body.ss-app-body.ss-pos-body[data-ss-typeface='lexend'][data-ss-density='comfortable'][data-ss-color-mode='light']"
    assert_selector "a.ss-skip-link[href='#main_content']", visible: :all
    assert_selector "header.ss-header[role='banner']"
    assert_selector "nav.ss-nav[aria-label='Primary navigation']"
    assert_selector "main#main_content.ss-main.ss-pos-main"
    assert_selector ".ss-pos-workspace-header[aria-label='Point of Sale workspace']"
  end
end
