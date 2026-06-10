# frozen_string_literal: true

require "test_helper"

class SetupTaxCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "taxadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.tax_categories.view setup.tax_categories.create setup.tax_categories.update
      setup.tax_categories.inactivate setup.tax_categories.reactivate setup.tax_categories.delete
    ].each { |key| grant_permission!(@admin, key) }
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "taxadmin", password: "Password123!" }
  end

  test "create tax category records audit event" do
    assert_difference -> { TaxCategory.count }, 1 do
      assert_difference -> { AuditEvent.where(event_name: "tax_category.created").count }, 1 do
        post setup_tax_categories_path, params: {
          tax_category: { name: "Maps", short_name: "Maps", sort_order: 70, active: true }
        }
      end
    end

    assert_redirected_to setup_tax_category_path(TaxCategory.last)
  end

  test "inactivate tax category records audit event" do
    tax_category = create_tax_category!(name: "Maps", short_name: "Maps")

    assert_difference -> { AuditEvent.where(event_name: "tax_category.inactivated").count }, 1 do
      patch inactivate_setup_tax_category_path(tax_category)
    end

    assert_not tax_category.reload.active?
  end
end
