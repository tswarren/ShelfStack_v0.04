# frozen_string_literal: true

require "test_helper"

class ItemsIngramImportControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "ingramadmin", password: "Password123!")
    grant_permission!(@admin, "items.access")
    grant_permission!(@admin, "items.ingram_import.run")
    @sub_department = create_sub_department!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "ingramadmin", password: "Password123!" }
    seed_phase3_reference_data!
  end

  test "requires import permission" do
    user = create_user!(username: "noimport", password: "Password123!")
    grant_permission!(user, "items.access")
    delete logout_path
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "noimport", password: "Password123!" }

    get items_ingram_import_path
    assert_redirected_to root_path
  end

  test "preview parses uploaded file" do
    file = fixture_file_upload("ingram_list_sample.xls", "application/vnd.ms-excel")

    assert_no_difference -> { ProductVariant.count } do
      post items_ingram_import_preview_path, params: {
        import_file: file,
        sub_department_id: @sub_department.id
      }
    end

    assert_redirected_to items_ingram_import_path
    follow_redirect!
    assert_match(/Parsed \d+ rows/, flash[:notice])
    assert_select "table.ss-table", minimum: 1
  end

  test "run import creates sellable sku" do
    file = fixture_file_upload("ingram_list_sample.xls", "application/vnd.ms-excel")
    post items_ingram_import_preview_path, params: {
      import_file: file,
      sub_department_id: @sub_department.id
    }

    before_count = ProductVariant.count
    post items_ingram_import_run_path, params: { sub_department_id: @sub_department.id }

    assert_operator ProductVariant.count - before_count, :>=, 1

    assert_redirected_to items_ingram_import_path
    follow_redirect!
    assert_match(/Import complete/, flash[:notice])
    assert AuditEvent.exists?(event_name: "ingram_import.completed")
  end

  test "run import with store category resolves category node" do
    file = fixture_file_upload("ingram_list_sample.xls", "application/vnd.ms-excel")
    store_category = store_category_node_for_tests
    post items_ingram_import_preview_path, params: {
      import_file: file,
      sub_department_id: @sub_department.id,
      store_category_id: store_category.id
    }

    post items_ingram_import_run_path, params: {
      sub_department_id: @sub_department.id,
      store_category_id: store_category.id
    }

    assert_redirected_to items_ingram_import_path
    follow_redirect!
    assert_match(/Import complete/, flash[:notice])
  end
end
