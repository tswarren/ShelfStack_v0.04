# frozen_string_literal: true

require "test_helper"

class Purchasing::LineEconomicsSyncTest < ActiveSupport::TestCase
  setup do
    seed_phase3_reference_data!
    @store = create_store!
    @vendor = create_vendor!(default_supplier_discount_bps: 4000)
    @variant = create_product_variant!(inventory_behavior: "standard_physical", selling_price_cents: 2500)
    @variant.product.update!(list_price_cents: 2000)
    @order = create_purchase_order!(
      store: @store,
      vendor: @vendor,
      lines: [ create_purchase_order_line_attrs(variant: @variant, vendor: @vendor, quantity_ordered: 2) ]
    )
    @line = @order.purchase_order_lines.first
  end

  test "changed_field_for returns unit cost when manual cost override set" do
    @line.manual_cost_override = true

    assert_equal "unit_cost_cents", Purchasing::LineEconomicsSync.changed_field_for(@line)
  end

  test "changed_field_for returns expected retail when manual price override set" do
    @line.manual_price_override = true

    assert_equal "expected_retail_price_cents", Purchasing::LineEconomicsSync.changed_field_for(@line)
  end

  test "apply preserves manual unit cost override" do
    @line.assign_attributes(
      unit_list_price_cents: 2000,
      supplier_discount_bps: 4000,
      unit_cost_cents: 1500,
      manual_cost_override: true
    )

    Purchasing::LineEconomicsSync.apply!(@line)

    assert_equal 1500, @line.unit_cost_cents
    assert @line.manual_cost_override
    assert_equal "manual", @line.cost_source
  end

  test "apply marks manual expected retail override" do
    @line.assign_attributes(expected_retail_price_cents: 3000, manual_price_override: true)

    Purchasing::LineEconomicsSync.apply!(@line)

    assert_equal 3000, @line.expected_retail_price_cents
    assert @line.manual_price_override
    assert_equal "manual", @line.price_source
  end

  test "apply marks manual cost source when supplier discount override recalculates cost" do
    @line.assign_attributes(
      unit_list_price_cents: 2000,
      supplier_discount_bps: 3000,
      unit_cost_cents: 1400,
      manual_cost_override: true
    )

    Purchasing::LineEconomicsSync.apply!(@line)

    assert @line.manual_cost_override
    assert_equal "manual", @line.cost_source
    assert_equal 3000, @line.supplier_discount_bps
    assert_equal 1400, @line.unit_cost_cents
  end

  test "apply sets both cost and price source manual when both overrides set" do
    @line.assign_attributes(
      unit_list_price_cents: 2000,
      supplier_discount_bps: 4000,
      unit_cost_cents: 1500,
      expected_retail_price_cents: 3200,
      manual_cost_override: true,
      manual_price_override: true
    )

    Purchasing::LineEconomicsSync.apply!(@line)

    assert_equal "manual", @line.cost_source
    assert_equal "manual", @line.price_source
    assert_equal 3200, @line.expected_retail_price_cents
    assert_equal 1500, @line.unit_cost_cents
  end
end
