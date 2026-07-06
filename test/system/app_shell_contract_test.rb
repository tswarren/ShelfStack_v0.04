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
    assert_selector "nav.ss-nav a.ss-nav__item--active[aria-current='page']", text: "Dashboard"
    assert_selector "main#main_content.ss-main"

    visit edit_pos_transaction_path(@transaction)

    assert_selector "body.ss-app-body.ss-pos-body[data-ss-typeface='lexend'][data-ss-density='comfortable'][data-ss-color-mode='light']"
    assert_selector "a.ss-skip-link[href='#main_content']", visible: :all
    assert_selector "header.ss-header[role='banner']"
    assert_selector "nav.ss-nav[aria-label='Primary navigation']"
    assert_selector "nav.ss-nav a.ss-nav__item--active[aria-current='page']", text: "POS"
    assert_selector "main#main_content.ss-main.ss-pos-main"
    assert_selector ".ss-pos-workspace-header[aria-label='Point of Sale workspace']"
  end

  test "permission-gated nav items expose disabled state" do
    user = create_user!(username: "restricted_#{SecureRandom.hex(4)}")
    store = create_store!
    workstation = create_workstation!(store: store)

    system_login!(user, workstation: workstation)
    visit root_path

    assert_selector "nav.ss-nav .ss-nav__item--disabled[aria-disabled='true']", text: "POS"
    assert_selector "nav.ss-nav .ss-nav__item--disabled[aria-disabled='true']", text: "Inventory"
    assert_no_selector "nav.ss-nav a", text: "POS"
  end

  test "flash messages can be dismissed" do
    setup_pos_system_sale!
    visit root_path

    all(".ss-flash__dismiss[aria-label='Dismiss message']", minimum: 0).each(&:click)

    find(".ss-dropdown-trigger", text: @cashier.display_name).click
    click_on "View mode"
    click_button "Compact View"

    assert_selector ".ss-flash", text: "Appearance updated.", wait: 5
    assert_selector ".ss-flash__dismiss[aria-label='Dismiss message']"

    find(".ss-flash__dismiss[aria-label='Dismiss message']").click

    assert_no_selector ".ss-flash"
  end
end
