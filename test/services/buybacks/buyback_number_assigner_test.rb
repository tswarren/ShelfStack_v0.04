# frozen_string_literal: true

require "test_helper"

class Buybacks::BuybackNumberAssignerTest < ActiveSupport::TestCase
  test "assigns workstation-scoped buyback number" do
    store = create_store!(store_number: "001")
    workstation = create_workstation!(store: store)
    workstation.update!(workstation_number: "003")
    user = create_user!
    customer = create_buyback_customer!
    session = Buybacks::StartSession.call!(store: store, customer: customer, actor: user, workstation: workstation)

    number = Buybacks::BuybackNumberAssigner.call!(session: session)

    assert_equal "001-003-B000001", number
    assert_equal number, session.reload.buyback_number
  end
end
