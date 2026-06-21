# frozen_string_literal: true

require "test_helper"

class CustomersCustomerLookupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
    @customer = create_customer!(display_name: "Lookup Test Customer", email: "lookup@example.com")
  end

  test "returns customer search results as json" do
    get customers_customer_lookup_path, params: { q: "Lookup", mode: "search" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "search", body["status"]
    assert(body["customers"].any? { |row| row["id"] == @customer.id })
  end

  test "create customer returns to request form with customer selected" do
    return_to = new_customers_customer_request_path

    post customers_customers_path, params: {
      return_to: return_to,
      customer: { display_name: "Return Flow Customer", email: "return@example.com" }
    }

    assert_redirected_to "#{return_to}?customer_id=#{Customer.last.id}"
    follow_redirect!
    assert_response :success
  end
end
