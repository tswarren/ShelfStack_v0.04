# frozen_string_literal: true

require "test_helper"

class Buybacks::SellerRequirementsChecklistTest < ActiveSupport::TestCase
  test "checklist returns structured rows and check returns missing messages" do
    customer = Customer.create!(display_name: "Partial Seller", first_name: "Pat", last_name: "Seller", active: true)
    rows = Buybacks::SellerRequirements.checklist(customer: customer)
    messages = Buybacks::SellerRequirements.check(customer: customer)

    assert rows.any? { |row| row[:key] == :address_line1 && !row[:met] }
    assert messages.any? { |message| message.include?("address") }
  end
end
