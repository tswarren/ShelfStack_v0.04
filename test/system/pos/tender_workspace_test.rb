# frozen_string_literal: true

require "application_system_test_case"

class PosTenderWorkspaceSystemTest < ApplicationSystemTestCase
  include Phase6TestHelper
  include PosSystemTestHelper

  setup do
    setup_pos_system_sale!
  end

  test "/cash opens settlement modal with cash draft prefilled" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/cash")

    within_settlement_modal do
      assert_text "Tender transaction"
      assert_selector ".ss-pos-tender-workspace__active-detail:not([hidden])", wait: 5
      assert_selector "[data-settlement-type='cash']"
    end
  end

  test "tender type hotkey 2 opens card draft" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/tender")

    within_settlement_modal do
      find("[data-hotkey='2']").click
      assert_selector ".ss-pos-tender-workspace__active-detail:not([hidden])", wait: 5
      assert_selector "[data-settlement-type='card']"
      assert_selector "select[name*='[card_brand]']"
    end
  end

  test "escape cancels active tender detail without saving" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/cash")

    within_settlement_modal do
      assert_selector ".ss-pos-tender-workspace__active-detail:not([hidden])", wait: 5
    end

    send_escape

    within_settlement_modal do
      assert_selector ".ss-pos-tender-workspace__active-detail[hidden]", visible: :all, wait: 5
      assert_text "No tenders saved yet."
    end
  end

  test "partial cash save keeps ready-to-complete hidden" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/cash")

    half = format("%.2f", (@transaction.total_cents / 200.0))
    within_settlement_modal do
      fill_in find("[data-pos-settlement-panel-target='amountField']")[:name], with: half
    end
    click_save_tender!
    assert_tender_saved!(label: "Cash")

    assert_settlement_modal_open!
    assert_ready_to_complete!(present: false)
  end

  test "full cash tender shows ready to complete without auto-completing" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/cash")
    click_save_tender!
    assert_tender_saved!(label: "Cash")

    assert_settlement_modal_open!
    assert_ready_to_complete!(present: true)
    assert @transaction.reload.draft?
  end

  test "ready to complete completes sale into completed workspace" do
    visit_pos_transaction_edit!
    open_settlement_via_command!("/cash")
    click_save_tender!
    assert_tender_saved!(label: "Cash")
    assert_ready_to_complete!(present: true)

    within_settlement_modal do
      click_button "Complete sale"
    end

    assert_text "SALE COMPLETE", wait: 15
    assert_current_path completed_pos_transaction_path(@transaction), wait: 15
    assert @transaction.reload.completed?
  end
end
