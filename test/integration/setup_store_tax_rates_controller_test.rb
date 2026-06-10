# frozen_string_literal: true

require "test_helper"

class SetupStoreTaxRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "strtaxadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.store_tax_rates.view setup.store_tax_rates.create setup.store_tax_rates.update
      setup.store_tax_rates.inactivate setup.store_tax_rates.reactivate setup.store_tax_rates.delete
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "strtaxadmin", password: "Password123!" }
  end

  test "create store tax rate records audit event" do
    assert_difference -> { StoreTaxRate.count }, 1 do
      post setup_store_tax_rates_path, params: {
        store_tax_rate: {
          store_id: @store.id,
          name: "County Tax",
          short_name: "County",
          tax_identifier: "C",
          tax_rate_bps: 250,
          active: true
        }
      }
    end

    rate = StoreTaxRate.last
    assert_redirected_to setup_store_tax_rate_path(rate)
    assert AuditEvent.exists?(event_name: "store_tax_rate.created", auditable: rate)
  end

  test "cannot delete store tax rate referenced by mapping" do
    rate = create_store_tax_rate!(store: @store, name: "Mapped Rate", tax_identifier: "M")
    create_store_tax_category_rate!(store: @store, store_tax_rate: rate)

    assert_no_difference -> { StoreTaxRate.count } do
      delete setup_store_tax_rate_path(rate)
    end

    assert_redirected_to setup_store_tax_rate_path(rate)
  end
end
