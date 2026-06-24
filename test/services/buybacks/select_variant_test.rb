# frozen_string_literal: true

require "test_helper"

class Buybacks::SelectVariantTest < ActiveSupport::TestCase
  setup do
    seed_phase7c_reference_data!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!
    grant_all_phase7c_permissions!(@user, store: @store)
    @customer = create_buyback_customer!
    @sub = buyback_sub_department!
    @condition = buyback_used_condition!
    @variant = create_product_variant!(sub_department: @sub, condition: @condition, selling_price_cents: 2000)
    @session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)
    @line = Buybacks::AddLine.call!(session: @session, actor: @user, title_snapshot: "Select Variant Book")
  end

  test "links variant and refreshes pricing" do
    Buybacks::SelectVariant.call!(line: @line, session: @session, variant: @variant, actor: @user)

    @line.reload
    assert_equal @variant.id, @line.product_variant_id
    assert_includes %w[resolved priced], @line.status
    assert @line.suggested_resale_price_cents.present? || @line.suggested_cash_offer_cents.present?
    assert AuditEvent.exists?(event_name: "buyback.line.variant_selected", auditable: @line)
  end

  test "rejects line from another session" do
    other_session = create_buyback_session!(store: @store, customer: @customer, actor: @user, workstation: @workstation)

    assert_raises(Buybacks::SelectVariant::Error) do
      Buybacks::SelectVariant.call!(line: @line, session: other_session, variant: @variant, actor: @user)
    end
  end
end
