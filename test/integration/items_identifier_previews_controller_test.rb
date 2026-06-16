# frozen_string_literal: true

require "test_helper"

class ItemsIdentifierPreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "idpreview", password: "Password123!")
    grant_permission!(@user, "items.access")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "idpreview", password: "Password123!" }
  end

  test "show returns validation preview json" do
    get items_identifier_preview_path, params: {
      identifier_type: "isbn13",
      value: "978-0-123456-78-0"
    }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "9780123456780", body["normalized"]
    assert_equal false, body["valid"]
    assert_match(/invalid/i, body["message"])
  end
end
