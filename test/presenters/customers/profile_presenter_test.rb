# frozen_string_literal: true

require "test_helper"

class CustomersProfilePresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    @store = create_store!
    @user = create_user!
    grant_all_phase7a_permissions!(@user, store: @store)
    @customer = create_customer!
  end

  test "counts open requests and exposes action paths" do
    create_customer_request!(store: @store, created_by_user: @user, customer: @customer)

    presenter = Customers::ProfilePresenter.build(customer: @customer, store: @store, user: @user)

    assert_equal 1, presenter.open_request_count
    assert presenter.can_create_request?
    assert_includes presenter.new_request_path, "customer_id=#{@customer.id}"
  end
end
