# frozen_string_literal: true

require "test_helper"

class PosHeldSalesLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "held_lifecycle_cashier_#{SecureRandom.hex(4)}")
    @store = create_store!(store_number: unique_store_number)
    @ctx = setup_pos_workstation!(user: @cashier, store: @store, login: true, inventory_qty: 0)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @variant = @ctx[:variant]

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      },
      lines: [
        { product_variant: @variant, quantity: 1, unit_price_cents: 1200, extended_price_cents: 1200 }
      ]
    )
  end

  test "suspend returns cashier to idle landing" do
    get edit_pos_transaction_path(@transaction)
    assert_response :success

    patch suspend_pos_transaction_path(@transaction)

    assert_redirected_to pos_root_path
    assert_equal "Transaction suspended.", flash[:notice]
    assert @transaction.reload.suspended?

    get pos_root_path

    assert_response :success
    assert_select "input[data-pos-command-bar-target='input']"
    assert_select "button", text: "Held sales (1)"
  end

  test "cashier resumes own held sale" do
    @transaction.update!(status: "suspended", suspended_at: Time.current)

    patch resume_pos_transaction_path(@transaction)

    assert_redirected_to edit_pos_transaction_path(@transaction)
    assert_equal "Transaction resumed.", flash[:notice]
    assert @transaction.reload.draft?
    assert_nil @transaction.suspended_at
  end

  test "other cashier blocked without other_cashier permission" do
    @transaction.update!(status: "suspended", suspended_at: Time.current)

    coworker = create_user!(username: "held_coworker_#{SecureRandom.hex(3)}")
    grant_permission!(coworker, "pos.access", store: @store)
    grant_permission!(coworker, "pos.transactions.resume", store: @store)
    grant_permission!(coworker, "pos.transactions.view", store: @store)
    grant_permission!(coworker, "pos.transactions.update", store: @store)
    delete logout_path
    login_user!(coworker, workstation: @workstation)

    patch resume_pos_transaction_path(@transaction)

    assert_redirected_to pos_root_path
    assert_match(/not authorized/i, flash[:alert].to_s)
    assert @transaction.reload.suspended?
  end

  test "lead resumes another cashiers held sale with other_cashier permission" do
    @transaction.update!(status: "suspended", suspended_at: Time.current)

    lead = create_user!(username: "held_lead_#{SecureRandom.hex(3)}")
    %w[
      pos.access
      pos.transactions.resume
      pos.transactions.resume.other_cashier
      pos.transactions.view
      pos.transactions.update
    ].each do |permission_key|
      grant_permission!(lead, permission_key, store: @store)
    end
    delete logout_path
    login_user!(lead, workstation: @workstation)

    patch resume_pos_transaction_path(@transaction)

    assert_redirected_to edit_pos_transaction_path(@transaction)
    assert @transaction.reload.draft?
  end
end
