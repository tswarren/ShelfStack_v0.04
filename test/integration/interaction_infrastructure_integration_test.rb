# frozen_string_literal: true

require "test_helper"

class InteractionInfrastructureIntegrationTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper
  test "interaction shell renders shared modal and drawer markup" do
    get test_interaction_shell_path

    assert_response :success
    assert_includes response.body, 'id="fixture-drawer"'
    assert_includes response.body, 'class="ss-drawer"'
    assert_includes response.body, 'role="dialog"'
    assert_includes response.body, 'aria-modal="true"'
    assert_includes response.body, 'id="fixture-modal"'
    assert_includes response.body, 'class="ss-modal"'
    assert_includes response.body, "data-action=\"drawer#open\""
    assert_includes response.body, "data-drawer-target-id-param=\"fixture-drawer\""
  end

  test "interaction shell turbo update replaces background panel" do
    post test_interaction_shell_turbo_update_path, as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="fixture-background-panel"'
    assert_includes response.body, "Background panel version:"
  end

  test "interaction shell append toast targets toast region" do
    post test_interaction_shell_append_toast_path,
         params: { message: "Saved.", variant: "success" },
         as: :turbo_stream

    assert_response :success
    assert_includes response.body, 'target="toast_region"'
    assert_includes response.body, "ss-toast--success"
    assert_includes response.body, "Saved."
  end

  test "application layout includes toast region when authenticated" do
    store = create_store!
    workstation = create_workstation!(store: store)
    user = create_user!(pin: "1234")
    grant_permission!(user, "items.access", store: store)
    login_user!(user, workstation: workstation)

    get items_root_path

    assert_response :success
    assert_includes response.body, 'id="toast_region"'
    assert_includes response.body, "ss-toast-region"
    assert_includes response.body, 'id="modal_close_triggers"'
    assert_includes response.body, 'id="demand_form_reset_triggers"'
  end
end
