# frozen_string_literal: true

require "test_helper"

class BuybacksExternalLookupMatchIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    grant_permission!(@user, "items.access", store: @store)
    grant_permission!(@user, "items.external_lookup.access", store: @store)
    grant_permission!(@user, "items.catalog_items.create", store: @store)
    grant_permission!(@user, "items.products.create", store: @store)
    grant_permission!(@user, "items.product_variants.create", store: @store)
    login_user!(@user, workstation: @workstation)

    @customer = create_buyback_customer!
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, identifier_entered: "9780123456789", title_snapshot: "Lookup Book")
    @variant = create_product_variant!(sku: "BUYBACKMATCH01")
  end

  test "add item identify preserves buyback match context" do
    get items_add_item_path(
      step: "choose_path",
      return_to: Buybacks::LineMatchContext::RETURN_TO,
      buyback_session_id: @session.id,
      line_id: @line.id
    )
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    follow_redirect!

    get items_add_item_path(step: "identify", isbn: @line.identifier_entered)
    assert_response :success
    assert_includes response.body, "Matching buyback"
    assert_includes response.body, "Return to buyback"
  end

  test "select variant from buyback line links item" do
    post select_variant_buybacks_session_line_path(@session, @line, product_variant_id: @variant.id),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal @variant.id, @line.reload.product_variant_id
    assert_includes response.media_type, "turbo-stream"
    assert_includes response.body, "buyback-line-row-#{@line.id}"
  end
end
