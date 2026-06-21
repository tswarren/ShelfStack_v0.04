# frozen_string_literal: true

require "test_helper"

class SetupExternalDataSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "setupuser", password: "Password123!")
    grant_permission!(@user, "setup.access")
    grant_permission!(@user, "items.external_lookup.configure")
    create_isbndb_source!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "setupuser", password: "Password123!" }
  end

  test "index lists external data sources" do
    get setup_external_data_sources_path
    assert_response :success
    assert_match(/ISBNdb/, response.body)
  end

  test "health check updates source status" do
    response = isbndb_response(status_code: 200, body: { "requests" => 1000, "requests_used" => 10, "requests_left" => 990 })
    client = stub_isbndb_client(response)
    original_new = ExternalCatalog::Provider::IsbndbClient.method(:new)
    ExternalCatalog::Provider::IsbndbClient.singleton_class.define_method(:new) { |**_| client }
    begin
      post setup_external_data_source_health_check_path("isbndb")
    ensure
      ExternalCatalog::Provider::IsbndbClient.singleton_class.define_method(:new, original_new)
    end

    assert_redirected_to setup_external_data_sources_path
    source = ExternalDataSource.find_by!(source_key: "isbndb")
    assert_equal "ok", source.last_health_check_status
  end
end
