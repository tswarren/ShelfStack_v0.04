# frozen_string_literal: true

require "test_helper"

class Pos::TenderValidatorTest < ActiveSupport::TestCase
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @user,
      attrs: { total_cents: 1000 },
      tenders: [{ tender_type: "gift_card", amount_cents: 1000 }]
    )
  end

  test "rejects gift card in phase 6" do
    error = assert_raises(Pos::TenderValidator::Error) { Pos::TenderValidator.validate!(@transaction) }
    assert_match(/gift_card/, error.message)
  end
end
