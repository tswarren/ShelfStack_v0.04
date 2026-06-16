# frozen_string_literal: true

require "test_helper"

class ItemsBisacSubjectSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "bisacsearch", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "bisacsearch", password: "Password123!" }
    seed_bisac_scheme!
  end

  test "search returns matching bisac nodes as json" do
    get items_bisac_subjects_search_path, params: { q: "Fantasy" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload["results"].any?
    assert payload["results"].all? { |result| result.key?("breadcrumb_label") }
  end

  test "search requires permission" do
    delete logout_path
    get items_bisac_subjects_search_path, params: { q: "Fantasy" }, as: :json

    assert_response :redirect
  end
end
