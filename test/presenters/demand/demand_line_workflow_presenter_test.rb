# frozen_string_literal: true

require "test_helper"

class DemandDemandLineWorkflowPresenterTest < ActiveSupport::TestCase
  include Phase7aTestHelper

  setup do
    Seeds::Phase7aPermissions.seed!
    seed_phase3_reference_data!
    @store = create_store!
    @user = create_user!
    @variant = create_product_variant!(inventory_behavior: "standard_physical")
    @customer = create_customer!
  end

  test "terminal demand shows no action required" do
    line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: @customer
    )
    line.update!(status: "fulfilled")
    presenter = build_presenter(line)

    assert_equal :terminal, presenter.next_action.key
  end

  test "captured demand suggests match variant" do
    line = DemandLines::CreateFromProvisional.call!(
      store: @store,
      actor: @user,
      provisional_title: "Unknown Book",
      customer_name_snapshot: "Walk-in",
      quantity: 1
    )
    presenter = build_presenter(line)

    assert_equal :match_variant, presenter.next_action.key
  end

  test "unallocated with on-hand suggests allocate" do
    InventoryBalance.find_or_create_by!(store: @store, product_variant: @variant) do |balance|
      balance.quantity_on_hand = 5
      balance.quantity_reserved = 0
      balance.quantity_available = 5
    end.update!(quantity_on_hand: 5, quantity_available: 5)

    line = DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "special_order",
      variant: @variant,
      customer: @customer
    )
    presenter = build_presenter(line)

    assert_equal :allocate_on_hand, presenter.next_action.key
  end

  private

  def build_presenter(line)
    Demand::DemandLineWorkflowPresenter.new(
      demand_line: line,
      store: @store,
      sourcing_unresolved: Sourcing::UnresolvedQuantity.for_demand_line(line),
      sourcing_eligibility: Sourcing::Eligibility.for_demand_line(line)
    )
  end
end
