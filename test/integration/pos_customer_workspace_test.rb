# frozen_string_literal: true

require "test_helper"

class PosCustomerWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @cashier = create_user!(username: "pos_customer_ws_cashier")
    @ctx = setup_pos_workstation!(user: @cashier, login: true, grant_permissions: false)
    @store = @ctx[:store]
    @workstation = @ctx[:workstation]
    @register_session = @ctx[:register_session]
    @customer = create_customer!(display_name: "POS Attach Customer", email: "posattach@example.com")

    grant_permission!(@cashier, "pos.access", store: @store)
    grant_permission!(@cashier, "pos.transactions.create", store: @store)
    grant_permission!(@cashier, "pos.transactions.update", store: @store)

    @transaction = create_pos_transaction!(
      store: @store,
      workstation: @workstation,
      user: @cashier,
      attrs: {
        pos_register_session: @register_session,
        business_date: @register_session.business_date
      }
    )
  end

  test "pos customer lookup works with pos.access only" do
    get pos_customer_lookup_path, params: { q: "POS Attach", mode: "search" }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "search", body["status"]
    assert(body["customers"].any? { |row| row["id"] == @customer.id })
  end

  test "pos customer lookup denied without pos.access" do
    restricted = create_user!(username: "pos_customer_ws_restricted")
    delete logout_path
    login_user!(restricted, workstation: @workstation)

    get pos_customer_lookup_path, params: { q: "POS Attach", mode: "search" }, as: :json

    assert_redirected_to pos_locked_out_path
  end

  test "customers customer lookup still requires customer_requests.access" do
    get customers_customer_lookup_path, params: { q: "POS Attach", mode: "search" }, as: :json

    assert_redirected_to customers_locked_out_path
  end

  test "attach_customer updates transaction customer" do
    patch attach_customer_pos_transaction_path(@transaction), params: { customer_id: @customer.id },
          headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal @customer.id, @transaction.reload.customer_id
    assert_match "turbo-stream", response.body
  end

  test "attach_customer rejects unknown customer" do
    patch attach_customer_pos_transaction_path(@transaction), params: { customer_id: 0 },
          headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_nil @transaction.reload.customer_id
  end

  test "attach_customer rejects inactive customer" do
    inactive = create_customer!(display_name: "Inactive POS Customer", active: false)

    patch attach_customer_pos_transaction_path(@transaction), params: { customer_id: inactive.id },
          headers: { Accept: "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_nil @transaction.reload.customer_id
  end

  test "detach_customer clears attached customer and records audit event" do
    @transaction.update!(customer: @customer)

    assert_difference -> { AuditEvent.where(event_name: "pos.transaction.customer_detached", auditable: @transaction).count }, 1 do
      patch detach_customer_pos_transaction_path(@transaction),
            headers: { Accept: "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_nil @transaction.reload.customer_id
    assert_match 'target="pos_customer_status"', response.body
  end

  test "start_sale with customer creates draft and attaches customer" do
    @transaction.update!(status: "cancelled")

    assert_difference -> { PosTransaction.drafts.count }, 1 do
      post pos_workspace_start_sale_path, params: { customer_id: @customer.id }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "redirect", body["action"]

    transaction = PosTransaction.drafts.order(:id).last
    assert_equal @customer.id, transaction.customer_id
  end

  test "start_sale with customer attaches customer to resumed draft" do
    @transaction.update!(customer: nil)

    assert_no_difference -> { PosTransaction.drafts.count } do
      post pos_workspace_start_sale_path, params: { customer_id: @customer.id }, as: :json
    end

    assert_response :success
    assert_equal @customer.id, @transaction.reload.customer_id
  end

  test "start_sale with invalid customer does not create draft" do
    assert_no_difference -> { PosTransaction.drafts.count } do
      post pos_workspace_start_sale_path, params: { customer_id: 0 }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "message", body["action"]
    assert_equal "Customer could not be found.", body["message"]
  end

  test "start_sale with customer requires update permission" do
    UserRoleAssignment.where(user: @cashier, store: @store).destroy_all
    grant_permission!(@cashier, "pos.access", store: @store)
    grant_permission!(@cashier, "pos.transactions.create", store: @store)

    assert_no_difference -> { PosTransaction.drafts.count } do
      post pos_workspace_start_sale_path, params: { customer_id: @customer.id }, as: :json
    end

    assert_response :forbidden
  end
end
