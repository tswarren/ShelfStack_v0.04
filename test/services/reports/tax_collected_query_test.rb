# frozen_string_literal: true

require "test_helper"

class Reports::TaxCollectedQueryTest < ActiveSupport::TestCase
  include Phase1TestHelper
  include Phase6TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "taxquery#{SecureRandom.hex(3)}")
    @transaction = create_pos_transaction!(status: "completed")
  end

  test "aggregates tax by applied source" do
    scope = Pos::ReportScope.from_params(
      store: @store,
      params: { business_date: Date.current.to_s }
    )

    result = Reports::TaxCollected::Query.call(scope: scope)
    assert result.total_tax_cents >= 0
    assert result.rows.any? { |row| row.row_type == :total }
  end

  private

  def create_pos_transaction!(status:)
    PosTransaction.create!(
      store: @store,
      workstation: @workstation,
      cashier_user: @user,
      status: status,
      transaction_type: "sale",
      business_date: Date.current,
      subtotal_cents: 1000,
      discount_cents: 0,
      tax_cents: 60,
      total_cents: 1060
    )
  end
end
