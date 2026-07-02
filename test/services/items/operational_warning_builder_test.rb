# frozen_string_literal: true

require "test_helper"

class Items::OperationalWarningBuilderTest < ActiveSupport::TestCase
  include Phase3TestHelper
  include V0047TestHelper

  setup do
    seed_phase3_reference_data!
    seed_phase5_reference_data!
    seed_v0047_permissions!
    @store = create_store!
    @user = create_user!
    grant_v0047_allocation_permissions!(@user, store: @store)
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
    DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "manual_tbo",
      quantity: 2,
      variant: @variant
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

  test "missing identifier appears once under data quality on item pages" do
    catalog_item = create_catalog_item!
    @product.product_identifiers.destroy_all
    @product.update!(catalog_item: catalog_item)

    warnings = Items::OperationalWarningBuilder.for_item(item: @item, store: @store, user: @user).fetch(@item, [])
    identifier_warnings = warnings.select { |warning| warning.code == :missing_identifier }

    assert_equal 1, identifier_warnings.size
    assert_equal :data_quality, identifier_warnings.first.category
    assert_nil identifier_warnings.first.variant_id
  end

  test "missing identifier appears once for multi variant items" do
    catalog_item = create_catalog_item!
    @product.product_identifiers.destroy_all
    @product.update!(catalog_item: catalog_item)

    2.times do |index|
      create_product_variant!(
        product: @product,
        sub_department: @variant.sub_department,
        sku: "#{@product.sku}-M#{index}"
      )
    end

    warnings = Items::OperationalWarningBuilder.for_item(item: @item, store: @store, user: @user).fetch(@item, [])
    identifier_warnings = warnings.select { |warning| warning.code == :missing_identifier }

    assert_equal 1, identifier_warnings.size
    assert_nil identifier_warnings.first.variant_id
  end

  test "for_items scopes open tbo warnings to item variants" do
    product_without_tbo = create_product!(sku: "NO-TBO-#{SecureRandom.hex(3)}")
    create_product_variant!(
      product: product_without_tbo,
      sub_department: @variant.sub_department,
      sku: "#{product_without_tbo.sku}-NEW"
    )
    item_without_tbo = Items::ItemPresenter.from_product(product_without_tbo)

    DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "manual_tbo",
      quantity: 2,
      variant: @variant
    )

    warnings_by_item = Items::OperationalWarningBuilder.for_items(
      store: @store,
      items: [ @item, item_without_tbo ],
      user: @user,
      contexts: [ :ordering ]
    )

    assert warnings_by_item.fetch(@item).any? { |warning| warning.code == :open_tbo }
    refute warnings_by_item.fetch(item_without_tbo).any? { |warning| warning.code == :open_tbo }
  end

  test "data quality context excludes open tbo warnings" do
    DemandLines::Create.call!(
      store: @store,
      actor: @user,
      capture_intent: "manual_tbo",
      quantity: 2,
      variant: @variant
    )

    warnings = Items::OperationalWarningBuilder.for_item(
      item: @item,
      store: @store,
      user: @user,
      contexts: [ :data_quality ]
    ).fetch(@item, [])

    refute warnings.any? { |warning| warning.code == :open_tbo }
  end

  test "for_variants batches order eligibility resolver" do
    resolver_calls = 0
    original = Purchasing::OrderEligibilityResolver.method(:for_variants)
    Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants) do |**args|
      resolver_calls += 1
      original.call(**args)
    end

    begin
      Items::OperationalWarningBuilder.for_variants(
        store: @store,
        variants: [ @variant, create_product_variant!(product: @product, sub_department: @variant.sub_department, sku: "#{@product.sku}-ALT") ],
        contexts: [ :ordering, :selling ]
      )
    ensure
      Purchasing::OrderEligibilityResolver.singleton_class.define_method(:for_variants, original)
    end

    assert_equal 1, resolver_calls
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

  test "non inventory variant without stock omits non_inventory info warning" do
    @variant.update!(inventory_behavior: "digital_asset")

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :inventory ]
    ).fetch(@variant.id, [])

    refute warnings.any? { |warning| warning.code == :non_inventory }
  end

  test "non inventory variant with stock still warns" do
    @variant.update!(inventory_tracking_override: "non_inventory", inventory_behavior: "standard_physical")
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      quantity_on_hand: 2,
      quantity_available: 2,
      quantity_reserved: 0
    )

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :inventory ]
    ).fetch(@variant.id, [])

    assert warnings.any? { |warning| warning.code == :non_inventory_with_stock }
  end

  test "inactive preferred vendor emits ordering warning" do
    vendor = create_vendor!
    vendor.update_column(:active, false)
    @product.update_column(:preferred_vendor_id, vendor.id)

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant.reload ],
      contexts: [ :ordering ]
    ).fetch(@variant.id, [])

    assert warnings.any? { |warning| warning.code == :inactive_preferred_vendor }
  end

  test "missing tax category when store has no applicable rate" do
    tax_category = create_tax_category!(
      name: "Unmapped #{SecureRandom.hex(3)}",
      short_name: "U#{SecureRandom.hex(2)}"
    )
    sub_department = SubDepartment.create!(
      sub_department_key: "unmapped_#{SecureRandom.hex(3)}",
      name: "Unmapped Subdept",
      short_name: "Unmapped",
      department: @variant.sub_department.department,
      default_tax_category: tax_category,
      default_pricing_model: "trade_discount",
      active: true
    )
    @variant.update!(sub_department: sub_department, selling_price_cents: 1299)
    StoreTaxCategoryRate.where(store: @store, tax_category: tax_category).delete_all

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :selling ]
    ).fetch(@variant.id, [])

    assert warnings.any? { |warning| warning.code == :missing_tax_category }
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

  test "used variant does not emit vendor sourcing ordering warnings" do
    used = ProductCondition.find_by(condition_key: "used_good") ||
      create_product_condition!(condition_key: "used_good_warn", name: "Used Good", short_name: "Used", new_condition: false, buyback_eligible: true)
    @variant.update!(condition: used, orderable: false)

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :ordering ]
    ).fetch(@variant.id, [])

    refute warnings.any? { |warning| warning.code == :missing_preferred_vendor }
    refute warnings.any? { |warning| warning.code == :missing_vendor_source }
    assert warnings.any? { |warning| warning.code == :used_not_vendor_orderable }
  end

  test "financial product type skips selling warnings" do
    @variant.product.update!(product_type: "financial")
    @variant.update!(selling_price_cents: 0)

    warnings = Items::OperationalWarningBuilder.for_variants(
      store: @store,
      variants: [ @variant ],
      contexts: [ :selling ]
    ).fetch(@variant.id, [])

    refute warnings.any? { |warning| warning.code == :missing_price }
  end
end
