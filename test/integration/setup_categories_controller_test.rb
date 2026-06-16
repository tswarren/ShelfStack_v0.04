# frozen_string_literal: true

require "test_helper"

class SetupCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "catadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    %w[
      setup.categories.view setup.categories.create setup.categories.update
      setup.categories.inactivate setup.categories.reactivate setup.categories.delete
    ].each { |key| grant_permission!(@admin, key) }
    @department = create_department!
    @tax_category = create_tax_category!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "catadmin", password: "Password123!" }
  end

  test "create category records audit event" do
    assert_difference -> { Category.count }, 1 do
      post setup_categories_path, params: {
        category: {
          department_id: @department.id,
          name: "Fiction",
          short_name: "Fiction",
          sort_order: 10,
          default_tax_category_id: @tax_category.id,
          active: true
        }
      }
    end

    assert_redirected_to setup_category_path(Category.last)
    assert AuditEvent.exists?(event_name: "category.created", auditable: Category.last)
  end

  test "validation failure renders form with field sections" do
    post setup_categories_path, params: {
      category: { department_id: @department.id, name: "", short_name: "" }
    }

    assert_response :unprocessable_entity
    assert_match "Basic Details", response.body
    assert_match "Defaults for Future SKUs", response.body
  end
end
