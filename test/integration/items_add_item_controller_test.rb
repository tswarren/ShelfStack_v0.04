# frozen_string_literal: true

require "test_helper"

class ItemsAddItemControllerTest < ActionDispatch::IntegrationTest
  include Phase3TestHelper

  setup do
    @store = create_store!
    @workstation = create_workstation!(store: @store)
    @user = create_user!(username: "wizarduser", password: "Password123!")
    grant_permission!(@user, "items.access")
    grant_permission!(@user, "items.catalog_items.create")
    grant_permission!(@user, "items.products.create")
    grant_permission!(@user, "items.product_variants.create")
    grant_permission!(@user, "items.catalog_items.view")
    @format = create_format!(format_key: "wizard_fmt", name: "Wizard Format", short_name: "WF")
    seed_phase3_reference_data!
    @sub_department = create_sub_department!
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "wizarduser", password: "Password123!" }
  end

  test "catalog-linked full path creates conditional product and variant" do
    get items_new_add_item_path
    assert_redirected_to items_add_item_path(step: "choose_path")

    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    assert_redirected_to items_add_item_path(step: "identify")

    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Wizard Book",
        catalog_item_type: "book",
        format_id: @format.id,
        creators: "Test Author"
      },
      commit: "Create Selling Setup"
    }
    assert_redirected_to items_add_item_path(step: "selling_setup")

    follow_redirect!
    assert_response :success

    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        list_price_cents: 2000,
        default_sub_department_id: @sub_department.id
      }
    }
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: {
          selling_price_cents: 2000,
          sub_department_id: @sub_department.id
        }
      }
    end

    item = CatalogItem.find_by!(title: "Wizard Book")
    product = item.products.first
    assert_equal "conditional", product.variation_type
    assert_equal @sub_department.id, product.default_sub_department_id
    assert_redirected_to items_item_path(catalog_item_id: item.id)
  end

  test "catalog-linked selling setup allows non-conditional variation type" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Variable Book",
        catalog_item_type: "book",
        format_id: @format.id
      },
      commit: "Create Selling Setup"
    }

    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        variation_type: "standard",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      },
      commit: "Done"
    }

    product = CatalogItem.find_by!(title: "Variable Book").products.first
    assert_equal "standard", product.variation_type
    assert_equal @sub_department.id, product.default_sub_department_id
  end

  test "catalog-linked selling setup shows variation type for service product type" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Service Catalog Item",
        catalog_item_type: "sideline",
        format_id: @format.id
      },
      commit: "Create Selling Setup"
    }
    follow_redirect!

    assert_select "select[name=\"product[variation_type]\"]", count: 1
    assert_select "select[name=\"product[product_type]\"] option[value='service']", count: 1
  end

  test "catalog-linked done after item details saves catalog only" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    assert_difference -> { CatalogItem.count }, 1 do
      assert_no_difference -> { Product.count } do
        post items_add_item_path(step: "item_details"), params: {
          catalog_item: {
            title: "Catalog Only Book",
            catalog_item_type: "book",
            format_id: @format.id
          },
          commit: "Done"
        }
      end
    end

    item = CatalogItem.find_by!(title: "Catalog Only Book")
    assert_redirected_to items_item_path(catalog_item_id: item.id)

    follow_redirect!
    assert_match "Catalog Only", response.body
  end

  test "non-catalog full path creates product and variant without catalog item" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    assert_redirected_to items_add_item_path(step: "selling_setup")

    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "FEE-001",
        name: "Bag Fee",
        product_type: "financial",
        variation_type: "matrix",
        variant1_label: "Denomination",
        variant2_label: "Series",
        list_price_cents: 10,
        default_sub_department_id: @sub_department.id
      }
    }
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: {
          sub_department_id: @sub_department.id,
          selling_price_cents: 10,
          attribute1_value: "25",
          attribute1_sku_component: "25",
          attribute2_value: "2024",
          attribute2_sku_component: "24"
        }
      }
    end

    product = Product.find_by!(sku: "FEE-001")
    assert_nil product.catalog_item
    assert_equal "matrix", product.variation_type
    assert_equal "pure_financial", product.product_variants.first.inventory_behavior
    assert_redirected_to items_item_path(product_id: product.id)
  end

  test "non-catalog done after selling setup creates product without variant" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }

    assert_difference -> { Product.count }, 1 do
      assert_no_difference -> { ProductVariant.count } do
        post items_add_item_path(step: "selling_setup"), params: {
          product: {
            sku: "DONE-SKU",
            name: "Done Product",
            product_type: "service",
            list_price_cents: 0,
            default_sub_department_id: @sub_department.id
          },
          commit: "Done"
        }
      end
    end

    product = Product.find_by!(sku: "DONE-SKU")
    assert_redirected_to items_item_path(product_id: product.id)

    follow_redirect!
    assert_match "Product Created", response.body
  end

  test "create sku and add another keeps wizard on sellable sku step" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "MULTI-001",
        name: "Multi Variant",
        product_type: "physical",
        variation_type: "conditional",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      }
    }

    condition_new = ProductCondition.find_by(condition_key: "new") || create_product_condition!(condition_key: "new", new_condition: true)
    used = ProductCondition.find_by(condition_key: "used") || create_product_condition!(condition_key: "used", short_name: "Used", new_condition: false, sku_component: "U")

    post items_add_item_path(step: "sellable_sku"), params: {
      product_variant: { condition_id: condition_new.id, sub_department_id: @sub_department.id, selling_price_cents: 1500 },
      commit: "Create SKU and Add Another"
    }
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: { condition_id: used.id, sub_department_id: @sub_department.id, selling_price_cents: 900, sku: "MULTI-001-U" },
        commit: "Create SKU"
      }
    end

    product = Product.find_by!(sku: "MULTI-001")
    assert_equal 2, product.product_variants.count
  end

  test "add item sellable sku honors non-inventory tracking selection" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "NONINV-001",
        name: "Non-Inventory Physical",
        product_type: "physical",
        variation_type: "standard",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      }
    }

    assert_difference -> { ProductVariant.count }, 1 do
      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: {
          sub_department_id: @sub_department.id,
          selling_price_cents: 1500,
          inventory_tracking: Inventory::TrackingResolver::NON_INVENTORY_TRACKING
        },
        commit: "Create SKU"
      }
    end

    variant = ProductVariant.order(:id).last
    assert_equal "non_inventory", variant.inventory_tracking_override
    assert_equal "non_inventory", variant.inventory_behavior
  end

  test "sellable sku step defaults selling price from list price" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "PRICE-001",
        name: "Priced Product",
        product_type: "physical",
        variation_type: "standard",
        list_price_cents: 2499,
        default_sub_department_id: @sub_department.id
      }
    }

    get items_add_item_path(step: "sellable_sku")
    assert_response :success
    assert_includes response.body, 'value="2499"'
  end

  test "sellable sku step defaults conditional price and sku for new condition" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "COND-001",
        name: "Conditional Product",
        product_type: "physical",
        variation_type: "conditional",
        list_price_cents: 2000,
        default_sub_department_id: @sub_department.id
      }
    }

    get items_add_item_path(step: "sellable_sku")
    assert_response :success
    assert_includes response.body, 'value="2000"'
    assert_includes response.body, 'data-variant-preview-target="skuPreview">COND-001</span>'
    assert_includes response.body, 'data-controller="variant-preview"'
    assert_not_includes response.body, 'name="product_variant[sku]" value="COND-001"'
  end

  test "non-catalog path does not require catalog item create permission" do
    delete logout_path
    user = create_user!(username: "nconly", password: "Password123!")
    grant_permission!(user, "items.access")
    grant_permission!(user, "items.products.create")
    grant_permission!(user, "items.product_variants.create")
    grant_permission!(user, "items.catalog_items.view")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "nconly", password: "Password123!" }

    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    assert_redirected_to items_add_item_path(step: "selling_setup")
  end

  test "invalid isbn13 during item details shows warning after save" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Invalid ISBN Book",
        catalog_item_type: "book",
        format_id: @format.id,
        initial_identifier_type: "isbn13",
        initial_identifier_value: "9780123456780"
      },
      commit: "Create Selling Setup"
    }

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Identifier saved with warning"
    assert_includes response.body, "ISBN-13 check digit is invalid"
  end

  test "duplicate primary identifier re-renders item details with warning and preserved fields" do
    existing = create_catalog_item!
    CatalogIdentifierService.add_identifier!(
      catalog_item: existing,
      identifier_type: "isbn13",
      value: "9780306406157",
      primary: true
    )

    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    assert_no_difference -> { CatalogItem.count } do
      post items_add_item_path(step: "item_details"), params: {
        catalog_item: {
          title: "Duplicate ISBN Book",
          catalog_item_type: "book",
          format_id: @format.id,
          creators: "Someone New",
          initial_identifier_type: "isbn13",
          initial_identifier_value: "978-0-306-40615-7"
        },
        commit: "Create Selling Setup"
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "already assigned"
    assert_includes response.body, existing.title
    assert_includes response.body, "Duplicate ISBN Book"
    assert_includes response.body, "Someone New"
    assert_includes response.body, 'value="978-0-306-40615-7"'
  end

  test "selling setup attaches cover image during add item wizard" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }

    cover = fixture_file_upload("cover.png", "image/png")
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        sku: "COVER-001",
        name: "Cover Product",
        product_type: "physical",
        list_price_cents: 1000,
        default_sub_department_id: @sub_department.id,
        cover_image: cover
      },
      commit: "Done"
    }

    product = Product.find_by!(sku: "COVER-001")
    assert product.cover_image.attached?
  end
end
