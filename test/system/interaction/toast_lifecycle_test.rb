# frozen_string_literal: true

require "application_system_test_case"

class InteractionToastLifecycleSystemTest < ApplicationSystemTestCase
  setup do
    visit test_interaction_shell_path
  end

  test "appends toast to region and dismiss removes it without focusing toast" do
    find("#fixture-append-toast-btn").click

    within "#toast_region" do
      assert_text "Fixture toast appended."
      assert_selector ".ss-toast--success"
    end

    assert_no_selector ".ss-toast button:focus"

    within "#toast_region" do
      click_button "Dismiss"
    end

    assert_selector "#toast_region .ss-toast", count: 0
  end
end
