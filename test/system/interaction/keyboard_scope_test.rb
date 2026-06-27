# frozen_string_literal: true

require "application_system_test_case"

class InteractionKeyboardScopeSystemTest < ApplicationSystemTestCase
  setup do
    visit test_interaction_shell_path
  end

  test "keyboard scope ignores keys from focused inputs" do
    host = find("#keyboard-scope-host")
    host.click
    host.send_keys("a")

    assert_equal "1", find("#keyboard-scope-key-count").text

    find("#keyboard-scope-input").click
    find("#keyboard-scope-input").send_keys("a")

    assert_equal "1", find("#keyboard-scope-key-count").text
  end
end
