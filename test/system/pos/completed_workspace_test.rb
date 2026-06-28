# frozen_string_literal: true

require "application_system_test_case"

class PosCompletedWorkspaceSystemTest < ApplicationSystemTestCase
  include Phase6TestHelper
  include PosSystemTestHelper

  setup do
    setup_pos_system_sale!
    complete_pos_sale!(
      transaction: @transaction,
      user: @cashier,
      register_session: @register_session
    )
    @transaction.reload
  end

  test "completed workspace focuses first document action" do
    visit completed_pos_transaction_path(@transaction)

    assert_text "SALE COMPLETE", wait: 10
    receipt = find("[data-pos-completed-workspace-target='receiptAction']", wait: 5)
    assert_equal receipt, page.active_element
  end

  test "enter on completed workspace opens first document" do
    visit completed_pos_transaction_path(@transaction)
    assert_text "SALE COMPLETE", wait: 10

    page.driver.browser.action.send_keys(:enter).perform

    assert_current_path pos_receipt_path(@transaction.pos_receipt, return_to: "completed"), wait: 15
  end

  test "new sale action returns to pos home" do
    visit completed_pos_transaction_path(@transaction)

    click_link "New Sale"

    assert_current_path pos_root_path, wait: 15
  end
end
