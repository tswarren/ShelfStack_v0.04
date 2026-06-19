# frozen_string_literal: true

require "test_helper"

class Pos::CompleteTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1000)
    @tax_category = @variant.sub_department.default_tax_category
    create_store_tax_category_rate!(store: @store, tax_category: @tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{
        product_variant: @variant,
        quantity: 1,
        unit_price_cents: 1000,
        extended_price_cents: 1000
      }]
    )
  end

  test "completes sale with inventory posting and receipt number" do
    complete_pos_sale!(transaction: @transaction, user: @user, register_session: @register_session)

    @transaction.reload
    assert @transaction.completed?
    assert_equal "sale", @transaction.transaction_type
    assert @transaction.transaction_number.present?
    assert_equal @transaction.transaction_number, @transaction.pos_receipt.receipt_number

    posting = @transaction.inventory_posting
    assert_not_nil posting
    assert_equal "pos_transaction", posting.posting_type
    assert_equal 1, posting.inventory_ledger_entries.count
    assert_equal "sold", posting.inventory_ledger_entries.first.movement_type
  end
end
