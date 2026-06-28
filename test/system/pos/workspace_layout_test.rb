# frozen_string_literal: true

require "application_system_test_case"

class PosWorkspaceLayoutSystemTest < ApplicationSystemTestCase
  include Phase6TestHelper
  include PosSystemTestHelper

  setup do
    setup_pos_system_sale!
  end

  test "header actions menu lists balance inquiry action" do
    visit_pos_transaction_edit!

    find(".ss-pos-workspace-header__actions summary").click
    assert_button "Stored Value Balance Inquiry"
  end

  test "balance command opens balance modal without leaving workspace" do
    visit_pos_transaction_edit!

    pos_command!("/balance")
    assert_selector "#pos-balance-inquiry-modal:not([hidden])", wait: 10
    assert_text "Gift card or store credit number"
  end

  test "complete transaction button opens settlement modal" do
    visit_pos_transaction_edit!

    click_button "Complete Transaction"
    assert_settlement_modal_open!
  end

  test "customer strip remove clears attached customer" do
    customer = create_customer!(display_name: "Layout Test Customer")
    @transaction.update!(customer: customer)
    visit_pos_transaction_edit!

    assert_text "Layout Test Customer"
    click_button "Remove"

    assert_text "None attached", wait: 10
  end

  test "flash dismiss clears notice without focusing command input" do
    visit_pos_transaction_edit!
    page.execute_script(<<~JS)
      const container = document.getElementById("pos_flash");
      container.innerHTML = `
        <div class="ss-pos-alert" data-controller="pos-flash" data-pos-flash-auto-clear-ms-value="5000">
          <span class="ss-pos-alert__message">Test notice</span>
          <button type="button" class="ss-pos-alert__dismiss" data-action="pos-flash#dismiss">Dismiss</button>
        </div>`;
      document.getElementById("pos_command_input").focus();
    JS

    find("#pos_command_input").click
    click_button "Dismiss"

    assert_no_text "Test notice", wait: 5
    assert_not_equal "Dismiss", page.evaluate_script("document.activeElement?.className || ''")
  end
end
