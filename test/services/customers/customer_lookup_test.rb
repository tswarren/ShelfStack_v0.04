# frozen_string_literal: true

require "test_helper"

class CustomersCustomerLookupTest < ActiveSupport::TestCase
  setup do
    @customer = create_customer!(display_name: "Ada Lovelace", email: "ada@example.com", phone: "555-0101")
  end

  test "exact match by email" do
    result = Customers::CustomerLookup.call(query: "ada@example.com", mode: :exact)

    assert_equal :found, result.status
    assert_equal @customer.id, result.customers.first.id
  end

  test "search by name prefix" do
    result = Customers::CustomerLookup.call(query: "Ada", mode: :search)

    assert_equal :search, result.status
    assert_includes result.customers.map(&:id), @customer.id
  end

  test "not found for unknown query" do
    result = Customers::CustomerLookup.call(query: "nobody@example.com", mode: :exact)

    assert_equal :not_found, result.status
    assert_empty result.customers
  end
end
