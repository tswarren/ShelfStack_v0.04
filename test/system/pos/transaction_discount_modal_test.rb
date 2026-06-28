# frozen_string_literal: true

require "application_system_test_case"

class PosTransactionDiscountModalSystemTest < ApplicationSystemTestCase
  include Phase6TestHelper

  setup do
    @cashier = create_user!(username: "txn_discount_sys_#{SecureRandom.hex(4)}", pin: "1234")
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(
      sku: "TXN-DISC-SYS-#{SecureRandom.hex(3)}",
      selling_price_cents: 1500
    )
    create_store_tax_category_rate!(
      store: @store,
      tax_category: @variant.sub_department.default_tax_category
    )

    @register_session = open_register_session!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      opening_cash_cents: 10_000
    )

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      lines: [
        {
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: 1500,
          extended_price_cents: 1500
        }
      ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    @gross_total = @transaction.total_cents
    @reason = DiscountReason.create!(
      reason_key: "txn_discount_sys_#{SecureRandom.hex(4)}",
      name: "System test discount"
    )

    system_login!(@cashier, workstation: @workstation)
  end

  test "sidebar launcher opens modal, applies discount, and refreshes summary on reopen" do
    visit edit_pos_transaction_path(@transaction)
    assert_selector "#pos-transaction-discount-modal[hidden]", visible: :all

    open_transaction_discount_modal_from_sidebar!

    select @reason.name, from: "transaction_discount_modal_discount_reason_id"
    fill_in "transaction_discount_modal_discount_value", with: "1.00"
    click_button "Apply discount"

    assert_selector "#pos-transaction-discount-modal[hidden]", visible: :all, wait: 10
    @transaction.reload
    assert_operator @transaction.total_cents, :<, @gross_total

    open_transaction_discount_modal_from_sidebar!

    within "#pos-transaction-discount-modal" do
      assert_text "Current transaction discount"
      assert_text "$1.00"
      assert_no_field "transaction_discount_modal_discount_value", with: "1.00"
    end
  end

  private

  def open_transaction_discount_modal_from_sidebar!
    find("summary", text: "Discount/Adjustment").click
    click_button "Apply transaction discount"
    assert_no_selector "#pos-transaction-discount-modal[hidden]", wait: 5

    reason_field = find("#transaction_discount_modal_discount_reason_id", wait: 5)
    assert_equal reason_field, page.active_element
  end
end
