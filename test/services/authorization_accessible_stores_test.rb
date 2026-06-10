# frozen_string_literal: true

require "test_helper"

class AuthorizationAccessibleStoresTest < ActiveSupport::TestCase
  test "accessible_stores returns all stores for global permission" do
    user = create_user!
    grant_permission!(user, "setup.store_tax_rates.view")

    stores = Authorization.accessible_stores(user: user, permission_key: "setup.store_tax_rates.view")
    assert_equal Store.count, stores.count
  end

  test "accessible_stores returns assigned store for store scoped permission" do
    store_one = create_store!(store_number: "001", name: "One")
    create_store!(store_number: "002", name: "Two")
    user = create_user!
    grant_permission!(user, "setup.store_tax_rates.view", store: store_one)

    stores = Authorization.accessible_stores(user: user, permission_key: "setup.store_tax_rates.view")
    assert_equal [ store_one.id ], stores.pluck(:id)
  end
end
