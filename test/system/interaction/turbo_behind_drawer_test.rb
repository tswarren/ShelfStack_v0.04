# frozen_string_literal: true

require "application_system_test_case"

class InteractionTurboBehindDrawerSystemTest < ApplicationSystemTestCase
  setup do
    visit test_interaction_shell_path
  end

  test "turbo stream updates background panel while drawer stays open" do
    original = find("#fixture-background-panel-content").text

    find("#open-drawer-button").click
    assert_no_selector "#fixture-drawer[hidden]"

    find("#fixture-turbo-update-in-drawer-btn").click
    assert_no_selector "#fixture-background-panel-content", text: original, wait: 5
    assert_no_selector "#fixture-drawer[hidden]"
  end
end
