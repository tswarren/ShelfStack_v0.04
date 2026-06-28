# frozen_string_literal: true

module PosSystemTestHelper
  def setup_pos_system_sale!(opening_cash_cents: 10_000, unit_price_cents: 1500, inventory_qty: 5)
    @cashier = create_user!(username: "pos_sys_#{SecureRandom.hex(4)}", pin: "1234")
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(
      sku: "POS-SYS-#{SecureRandom.hex(3)}",
      selling_price_cents: unit_price_cents
    )
    create_store_tax_category_rate!(
      store: @store,
      tax_category: @variant.sub_department.default_tax_category
    )
    if inventory_qty.positive?
      receive_inventory!(
        store: @store,
        vendor: create_vendor!,
        variant: @variant,
        user: @cashier,
        quantity: inventory_qty
      )
    end

    @register_session = open_register_session!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      opening_cash_cents: opening_cash_cents
    )

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      },
      lines: [
        {
          product_variant: @variant,
          quantity: 1,
          unit_price_cents: unit_price_cents,
          extended_price_cents: unit_price_cents
        }
      ]
    )
    Pos::RecalculateTransaction.call!(@transaction, business_date: @register_session.business_date)
    @transaction.reload

    system_login!(@cashier, workstation: @workstation)
  end

  def visit_pos_transaction_edit!
    visit edit_pos_transaction_path(@transaction)
    assert_selector "#pos_command_input", wait: 10
  end

  def pos_command!(input)
    fill_in "pos_command_input", with: input
    find("#pos_command_input").send_keys(:enter)
  end

  def open_settlement_via_command!(input = "/cash")
    pos_command!(input)
    assert_settlement_modal_open!
  end

  def assert_settlement_modal_open!
    assert_no_selector "#pos_settlement_modal[hidden]", wait: 10
  end

  def assert_settlement_modal_closed!
    assert_selector "#pos_settlement_modal[hidden]", visible: :all, wait: 10
  end

  def within_settlement_modal(&block)
    within "#pos_settlement_modal", visible: :all, &block
  end

  def settlement_active_detail
    within_settlement_modal do
      find(".ss-pos-tender-workspace__active-detail", visible: :all)
    end
  end

  def click_save_tender!
    within_settlement_modal do
      click_button "Save tender"
    end
  end

  def assert_tender_saved!(label: nil)
    within_settlement_modal do
      assert_selector ".ss-pos-tender-workspace__active-detail[hidden]", visible: :all, wait: 15
      assert_no_text "No tenders saved yet.", wait: 15
      assert_text label, wait: 15 if label
    end
  end

  def assert_ready_to_complete!(present: true)
    if present
      within_settlement_modal do
        assert_text "Ready to complete", wait: 15
        complete_btn = find(".ss-pos-settlement-complete-btn", wait: 5)
        assert_not complete_btn.disabled?, "expected Complete sale to be enabled"
      end
    else
      within_settlement_modal do
        assert_no_text "Ready to complete", wait: 5
      end
    end
  end
end
