# frozen_string_literal: true

require "test_helper"

class PosTransactionsTurboStreamTest < ActionDispatch::IntegrationTest
  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @cashier = create_user!(username: "cashier_turbo")
    grant_all_phase6_permissions!(@cashier, store: @store)

    @variant = create_product_variant!(sku: "TURBO-001", selling_price_cents: 1500)
    create_store_tax_category_rate!(store: @store, tax_category: @variant.sub_department.default_tax_category)
    receive_inventory!(store: @store, vendor: create_vendor!, variant: @variant, user: @cashier, quantity: 5)

    login_user!(@cashier, workstation: @workstation)
    open_register_session!(store: @store, workstation: @workstation, user: @cashier, opening_cash_cents: 10_000)

    post pos_transactions_path, params: { mode: "sale" }
    @transaction = PosTransaction.order(:id).last
  end

  test "add line responds with turbo stream" do
    post add_line_pos_transaction_path(@transaction),
      params: {
        product_variant_id: @variant.id,
        quantity: 1,
        entry_action: "sale"
      },
      headers: {
        "Accept" => "text/vnd.turbo-stream.html",
        "Turbo-Frame" => "none"
      }

    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "pos_cart"
    assert_equal 1, @transaction.reload.pos_transaction_lines.count
  end
end
