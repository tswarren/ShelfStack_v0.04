# frozen_string_literal: true

require "application_system_test_case"

class InteractionModalDrawerShellSystemTest < ApplicationSystemTestCase
  setup do
    visit test_interaction_shell_path
  end

  test "drawer opens, traps focus, and restores opener on close" do
    assert_selector "#fixture-drawer[hidden]", visible: :hidden

    find("#open-drawer-button").click
    assert_no_selector "#fixture-drawer[hidden]"

    assert_equal find("#fixture-drawer-field"), page.active_element

    find(".ss-drawer-close").click
    assert_selector "#fixture-drawer[hidden]", visible: :hidden
    assert_equal find("#open-drawer-button"), page.active_element
  end

  test "drawer closes on escape when form is clean" do
    find("#open-drawer-button").click
    assert_no_selector "#fixture-drawer[hidden]"

    send_escape
    assert_selector "#fixture-drawer[hidden]", visible: :hidden
    assert_equal find("#open-drawer-button"), page.active_element
  end

  test "drawer does not close on escape when form is dirty" do
    find("#open-drawer-button").click
    find("#fixture-drawer-dirty-field").fill_in with: "changed"

    send_escape
    assert_no_selector "#fixture-drawer[hidden]"
  end

  test "dirty drawer closes via explicit close button" do
    find("#open-drawer-button").click
    find("#fixture-drawer-dirty-field").fill_in with: "changed"

    send_escape
    assert_no_selector "#fixture-drawer[hidden]"

    find(".ss-drawer-close").click
    assert_selector "#fixture-drawer[hidden]", visible: :hidden
    assert_equal find("#open-drawer-button"), page.active_element
  end

  test "dirty drawer releases body lock when turbo removes drawer element" do
    find("#open-drawer-button").click
    find("#fixture-drawer-dirty-field").fill_in with: "changed"
    assert page.evaluate_script("document.body.classList.contains('ss-drawer-open')")

    find("#fixture-replace-drawer-btn").click
    assert_selector "#fixture-drawer-replaced", visible: :all, wait: 5
    assert page.evaluate_script("!document.body.classList.contains('ss-drawer-open')")
  end

  test "modal opens, focuses first field, and closes on backdrop when allowed" do
    find("#open-modal-button").click
    assert_no_selector "#fixture-modal[hidden]"
    assert_equal find("#fixture-modal-field"), page.active_element

    find(".ss-modal-overlay").click
    assert_selector "#fixture-modal[hidden]", visible: :hidden
    assert_equal find("#open-modal-button"), page.active_element
  end

  test "nested modal keeps body locked while drawer remains open" do
    find("#open-drawer-button").click
    assert_no_selector "#fixture-drawer[hidden]"
    assert page.evaluate_script("document.body.classList.contains('ss-drawer-open')")

    within "#fixture-drawer" do
      find("#open-nested-modal-button").click
    end
    assert_no_selector "#fixture-nested-modal[hidden]"
    assert page.evaluate_script("document.body.classList.contains('ss-modal-open')")

    find("#fixture-nested-modal .ss-modal-close").click
    assert_selector "#fixture-nested-modal[hidden]", visible: :hidden
    assert page.evaluate_script("!document.body.classList.contains('ss-modal-open')")
    assert page.evaluate_script("document.body.classList.contains('ss-drawer-open')")

    find("#fixture-drawer .ss-drawer-close").click
    assert_selector "#fixture-drawer[hidden]", visible: :hidden
    assert page.evaluate_script("!document.body.classList.contains('ss-drawer-open')")
  end
end
