# frozen_string_literal: true

require "test_helper"

class BuybacksUxContractTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    login_user!(@user, workstation: @workstation)
  end

  test "buybacks home uses page header with primary new action" do
    get buybacks_root_path

    assert_response :success
    assert_select ".ss-page-header h1", text: "Buybacks"
    assert_select ".ss-page-actions .ss-btn-primary", text: "New buyback"
  end

  test "new buyback session form uses contract footer actions" do
    create_customer!

    get new_buybacks_session_path

    assert_response :success
    assert_select "footer.ss-form-actions button.ss-btn-primary", text: "Start session"
    assert_select "footer.ss-form-actions a.ss-btn-tertiary", text: "Cancel"
  end
end
