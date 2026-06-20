# frozen_string_literal: true

require "test_helper"

class Pos::VoidTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 1000)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @user, quantity: 5)
    @register_session = open_register_session!(store: @store, workstation: @workstation, user: @user)
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      lines: [{ product_variant: @variant, quantity: 1, unit_price_cents: 1000, extended_price_cents: 1000 }]
    )
    complete_pos_sale!(transaction: @transaction, user: @user, register_session: @register_session)
    @transaction.reload
  end

  test "void creates pos_void posting and reversing tenders" do
    pos_void = Pos::VoidTransaction.call!(
      transaction: @transaction,
      voided_by_user: @user,
      register_session: @register_session,
      reason_code: "cashier_error"
    )

    @transaction.reload
    assert @transaction.voided?
    assert_not_nil pos_void.inventory_posting
    assert_equal "pos_void", pos_void.inventory_posting.posting_type
    assert_equal @transaction.inventory_posting, pos_void.inventory_posting.reversal_of_posting
    assert @transaction.pos_tenders.where.not(reverses_tender_id: nil).exists?
    assert_equal 5, InventoryBalance.find_by!(store: @store, product_variant: @variant).quantity_on_hand
  end
end
