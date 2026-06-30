# frozen_string_literal: true

require "test_helper"

class ItemsProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Seeds::Phase3Permissions.seed!
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @admin = create_user!(username: "variantadmin", password: "Password123!")
    grant_permission!(@admin, "items.access")
    %w[
      items.product_variants.view items.product_variants.create items.product_variants.update
      items.product_variants.inactivate items.product_variants.reactivate items.product_variants.delete
    ].each { |key| grant_permission!(@admin, key) }
    @product = create_product!(variation_type: "conditional")
    @sub_department = create_sub_department!
    @used_condition = ProductCondition.active_records.find_by(new_condition: false) ||
                      create_product_condition!(condition_key: "used_test", name: "Used Test", short_name: "Used", new_condition: false, sku_component: "U", sort_order: 50)
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "variantadmin", password: "Password123!" }
  end

  test "create variant with return_to item redirects to selling tab with variant highlight" do
    assert_difference -> { ProductVariant.count }, 1 do
      post items_product_variants_path(return_to: "item"), params: {
        product_variant: {
          product_id: @product.id,
          condition_id: @used_condition.id,
          sub_department_id: @sub_department.id,
          selling_price_cents: 899,
          inventory_behavior: "standard_physical",
          active: true
        }
      }
    end

    variant = ProductVariant.order(:id).last
    expected_sku = SkuGenerator.preview_variant_sku(product: @product, condition: @used_condition)
    assert_equal expected_sku, variant.sku
    assert_redirected_to items_item_path(
      product_id: @product.id,
      tab: "item_setup",
      variant_id: variant.id
    )
  end

  test "update variant with return_to item redirects to selling tab with variant highlight" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    patch items_product_variant_path(variant, return_to: "item"), params: {
      product_variant: {
        product_id: @product.id,
        condition_id: variant.condition_id,
        sub_department_id: variant.sub_department_id,
        selling_price_cents: 1299,
        inventory_behavior: variant.inventory_behavior,
        active: true
      }
    }

    assert_redirected_to items_item_path(
      product_id: @product.id,
      tab: "item_setup",
      variant_id: variant.id
    )
    assert_equal 1299, variant.reload.selling_price_cents
  end

  test "new variant form leaves sku blank for generation" do
    get new_items_product_variant_path(product_id: @product.id, condition_id: @used_condition.id, return_to: "item")

    assert_response :success
    assert_select "input[name='product_variant[sku]']" do |elements|
      assert elements.first["value"].blank?
    end
  end

  test "update variant with inventory tracking selection syncs behavior" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    patch items_product_variant_path(variant, return_to: "item"), params: {
      product_variant: {
        product_id: @product.id,
        condition_id: variant.condition_id,
        sub_department_id: variant.sub_department_id,
        selling_price_cents: variant.selling_price_cents,
        inventory_tracking: "non_inventory",
        active: true
      }
    }

    variant.reload
    assert_equal "non_inventory", variant.inventory_tracking_override
    assert_equal "non_inventory", variant.inventory_behavior
  end

  test "update variant without return_to param still redirects to item selling tab" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    patch items_product_variant_path(variant), params: {
      product_variant: {
        product_id: @product.id,
        condition_id: variant.condition_id,
        sub_department_id: variant.sub_department_id,
        selling_price_cents: 1399,
        inventory_behavior: variant.inventory_behavior,
        active: true
      }
    }

    assert_redirected_to items_item_path(
      product_id: @product.id,
      tab: "item_setup",
      variant_id: variant.id
    )
  end

  test "new variant from product locks product on form" do
    get new_items_product_variant_path(product_id: @product.id, return_to: "item")

    assert_response :success
    assert_select 'input[type=hidden][name="product_variant[product_id]"][value=?]', @product.id.to_s
    assert_select "select[name='product_variant[product_id]']", count: 0
    assert_select 'input[type=hidden][name="return_to"][value="item"]', count: 1
    assert_match "Variation type", response.body
    assert_match "Conditional", response.body
  end

  test "new variant without product shows product picker helper" do
    get new_items_product_variant_path(return_to: "item")

    assert_response :success
    assert_select "select[name='product_variant[product_id]']", count: 1
    assert_match "variation type", response.body
    assert_match "variant-product-picker", response.body
  end

  test "new variant for digital product defaults to non-inventory tracking" do
    digital_product = create_product!(product_type: "digital", sku: "DIG-#{SecureRandom.hex(3)}")

    get new_items_product_variant_path(product_id: digital_product.id, return_to: "item")

    assert_response :success
    assert_select "select[name='product_variant[inventory_tracking]']" do |elements|
      assert_equal Inventory::TrackingResolver::NON_INVENTORY_TRACKING, elements.first.css("option[selected]").first["value"]
    end
  end

  test "edit variant hides legacy behavior editor without manage permission" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    get edit_items_product_variant_path(variant, return_to: "item")

    assert_response :success
    assert_select "select[name='product_variant[inventory_behavior]']", count: 0
    assert_match "Legacy inventory behavior can only be edited by support staff", response.body
  end

  test "edit variant shows legacy behavior editor with manage permission" do
    grant_permission!(@admin, "items.product_variants.manage_inventory_behavior")
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    get edit_items_product_variant_path(variant, return_to: "item")

    assert_response :success
    assert_select "select[name='product_variant[inventory_behavior]']", count: 1
  end

  test "create variant for digital product seeds non-inventory behavior" do
    digital_product = create_product!(product_type: "digital", sku: "DIG-#{SecureRandom.hex(3)}")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_product_variants_path(return_to: "item"), params: {
        product_variant: {
          product_id: digital_product.id,
          condition_id: @used_condition.id,
          sub_department_id: @sub_department.id,
          selling_price_cents: 899,
          inventory_tracking: Inventory::TrackingResolver::NON_INVENTORY_TRACKING,
          active: true
        }
      }
    end

    variant = ProductVariant.order(:id).last
    assert_equal "digital_asset", variant.inventory_behavior
    assert_equal "non_inventory", variant.inventory_tracking_override
  end

  test "update variant without manage permission ignores submitted legacy behavior" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)
    variant.update!(
      inventory_tracking_override: Inventory::TrackingResolver::NON_INVENTORY_TRACKING,
      inventory_behavior: "non_inventory"
    )

    patch items_product_variant_path(variant, return_to: "item"), params: {
      product_variant: {
        product_id: @product.id,
        condition_id: variant.condition_id,
        sub_department_id: variant.sub_department_id,
        selling_price_cents: 1499,
        inventory_behavior: "standard_physical",
        active: true
      }
    }

    assert_redirected_to items_item_path(
      product_id: @product.id,
      tab: "item_setup",
      variant_id: variant.id
    )
    variant.reload
    assert_equal 1499, variant.selling_price_cents
    assert_equal "non_inventory", variant.inventory_tracking_override
    assert_equal "non_inventory", variant.inventory_behavior
  end

  test "create preserves explicit orderable true for non-inventory variant" do
    seed_phase3_reference_data!
    @product.update!(product_type: "non_inventory")
    new_condition = ProductCondition.find_by!(condition_key: "new")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_product_variants_path, params: {
        product_variant: {
          product_id: @product.id,
          condition_id: new_condition.id,
          sub_department_id: @sub_department.id,
          selling_price_cents: 500,
          inventory_behavior: "non_inventory",
          orderable: true,
          active: true
        }
      }
    end

    assert ProductVariant.order(:id).last.orderable?
  end

  test "variant show includes back to item link" do
    variant = create_product_variant!(product: @product, sub_department: @sub_department)

    get items_product_variant_path(variant)

    assert_response :success
    assert_match "tab=item_setup", response.body
    assert_match "variant_id=#{variant.id}", response.body
    assert_match "Back to Item", response.body
  end
end
