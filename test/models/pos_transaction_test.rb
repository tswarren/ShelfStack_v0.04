# frozen_string_literal: true

require "test_helper"

class PosTransactionTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @transaction = create_pos_transaction!(store: @store, workstation: @workstation, user: @user)
  end

  test "completed transactions are immutable" do
    @transaction.update!(status: "completed", completed_at: Time.current, transaction_number: "001-001-000001")

    assert_not @transaction.update(notes: "changed")
    assert_includes @transaction.errors[:base], "completed transactions are immutable"
  end
end
