# frozen_string_literal: true

require "test_helper"

class CustomersProfilePresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    Seeds::V0046Permissions.seed!
    @store = create_store!
    @customer = create_customer!
  end

  test "counts open demand lines and exposes demand path when demand.create granted" do
    user = create_user!
    grant_permission!(user, "demand.create", store: @store)
    grant_permission!(user, "demand.access", store: @store)

    DemandLines::CreateFromProvisional.call!(
      store: @store,
      actor: user,
      customer: @customer,
      provisional_title: "Open request"
    )

    presenter = Customers::ProfilePresenter.build(customer: @customer, store: @store, user: user)

    assert_equal 1, presenter.open_request_count
    refute presenter.can_create_request?
    assert presenter.can_create_demand?
    assert_includes presenter.new_demand_path, "customer_id=#{@customer.id}"
  end

  test "demand-capable users get new demand path" do
    user = create_user!
    grant_permission!(user, "demand.create", store: @store)

    presenter = Customers::ProfilePresenter.build(customer: @customer, store: @store, user: user)

    assert presenter.can_create_demand?
    refute presenter.can_create_request?
    assert_includes presenter.new_demand_path, "customer_id=#{@customer.id}"
  end
end
