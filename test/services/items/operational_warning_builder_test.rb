# frozen_string_literal: true

require "test_helper"

class Items::OperationalWarningBuilderTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    @store = create_store!
    @user = create_user!
    @product = create_product!
    @variant = create_product_variant!(product: @product, inventory_behavior: "standard_physical", selling_price_cents: 0)
    @item = Items::ItemPresenter.from_product(@product)
    grant_all_phase5_permissions!(@user, store: @store)
    grant_permission!(@user, "inventory.access", store: @store)
    grant_permission!(@user, "inventory.balances.view", store: @store)
  end

  test "delegates ordering warnings from eligibility resolver for variant call" do
    warnings = Items::OperationalWarningBuilder.call(product_variant: @variant, contexts: [ :ordering ], store: @store)

    assert warnings.any? { |warning| warning.category == :ordering }
    assert warnings.any? { |warning| warning.code == :missing_preferred_vendor }
  end

  test "for_item includes selling and open tbo warnings" do
    PurchaseRequest.create!(store: @store, status: "open").purchase_request_lines.create!(
      product_variant: @variant,
      requested_quantity: 2,
      status: "open"
    )

    warnings = Items::OperationalWarningBuilder.for_item(item: @item, store: @store, user: @user).fetch(@item, [])

    assert warnings.any? { |warning| warning.code == :missing_price }
    assert warnings.any? { |warning| warning.code == :open_tbo }
  end

  test "for_variants returns hash keyed by variant id" do
    warnings_by_variant = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :ordering ]
    )

    assert warnings_by_variant.key?(@variant.id)
  end

  test "inventory tracking mismatch when override conflicts with behavior" do
    @variant.update!(
      inventory_tracking_override: "inventory",
      inventory_behavior: "digital_asset"
    )

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :inventory ]
    ).fetch(@variant.id, [])

    assert warnings.any? { |warning| warning.code == :inventory_tracking_mismatch }
  end

  test "worst_severity prefers blocking over warning" do
    warnings = [
      Items::OperationalWarningBuilder::Warning.new(
        severity: :warning, category: :selling, code: :missing_price, message: "x",
        variant_id: nil, corrective_path: nil, corrective_label: nil, source: :test
      ),
      Items::OperationalWarningBuilder::Warning.new(
        severity: :blocking, category: :ordering, code: :inactive_variant, message: "y",
        variant_id: nil, corrective_path: nil, corrective_label: nil, source: :test
      )
    ]

    assert_equal :blocking, Items::OperationalWarningBuilder.worst_severity(warnings)
  end
end
