# frozen_string_literal: true

require "test_helper"

class SetupMerchandiseClassesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "mcadmin", password: "Password123!")
    grant_permission!(@admin, "setup.access")
    grant_all_phase3b_permissions!(@admin)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "mcadmin", password: "Password123!" }
    @tax_category = create_tax_category!
  end

  test "create merchandise class" do
    post setup_merchandise_classes_path, params: {
      merchandise_class: {
        merchandise_class_key: "sidelines",
        name: "Sidelines Test",
        short_name: "Sidelines T",
        default_tax_category_id: @tax_category.id,
        active: true
      }
    }

    merchandise_class = MerchandiseClass.find_by!(merchandise_class_key: "sidelines")
    assert_equal "Sidelines Test", merchandise_class.name
    assert AuditEvent.exists?(event_name: "merchandise_class.created", auditable: merchandise_class)
  end
end
