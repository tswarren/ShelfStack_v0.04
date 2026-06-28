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

  test "completed workspace focuses new sale action" do
    visit completed_pos_transaction_path(@transaction)

    assert_text "SALE COMPLETE", wait: 10
    new_sale = find("[data-pos-completed-workspace-target='newSaleAction']", wait: 5)
    assert_equal new_sale, page.active_element
  end

  test "enter on completed workspace starts a fresh draft" do
    visit completed_pos_transaction_path(@transaction)
    assert_text "SALE COMPLETE", wait: 10

    page.driver.browser.action.send_keys(:enter).perform

    assert_selector "#pos_command_input", wait: 15
    new_draft = PosTransaction.drafts.order(:id).last
    assert_not_equal @transaction.id, new_draft.id
    assert_current_path edit_pos_transaction_path(new_draft, mode: "sale"), wait: 10
  end

  test "new sale button starts a fresh draft" do
    visit completed_pos_transaction_path(@transaction)

    click_button "New Sale"

    assert_selector "#pos_command_input", wait: 15
    new_draft = PosTransaction.drafts.order(:id).last
    assert_not_equal @transaction.id, new_draft.id
  end
end
