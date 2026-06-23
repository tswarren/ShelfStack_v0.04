# frozen_string_literal: true

require "test_helper"

class Pos::GiftCardSaleSupportTest < ActiveSupport::TestCase
  test "activation_ready accepts generate identifier flag" do
    line = PosTransactionLine.new(line_type: "gift_card_sale", generate_stored_value_identifier: true)

    assert Pos::GiftCardSaleSupport.activation_ready?(line)
  end

  test "activation_ready accepts stored value account" do
    line = PosTransactionLine.new(line_type: "gift_card_sale", stored_value_account_id: 1)

    assert Pos::GiftCardSaleSupport.activation_ready?(line)
  end

  test "validate_amount rejects non-positive values" do
    assert_raises(ArgumentError) { Pos::GiftCardSaleSupport.validate_amount!(0) }
  end
end
