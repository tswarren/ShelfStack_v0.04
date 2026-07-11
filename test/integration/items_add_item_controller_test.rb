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
    assert_redirected_to items_add_item_path(step: "item_details")

    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Wizard Book",
        catalog_item_type: "book",
        format_id: @format.id,
        creators: "Test Author",
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

    item = Product.find_by!(title: "Wizard Book")
    assert_nil item.catalog_item_id
    assert_equal "conditional", item.variation_type
    assert_equal @sub_department.id, item.default_sub_department_id
    assert_redirected_to items_item_path(product_id: item.id)
  end

  test "item details can set non-conditional variation type before create variant" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Variable Book",
        catalog_item_type: "book",
        format_id: @format.id,
        variation_type: "standard",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      },
      commit: "Save Product Only"
    }

    product = Product.find_by!(title: "Variable Book")
    assert_equal "standard", product.variation_type
    assert_equal @sub_department.id, product.default_sub_department_id
  end

  test "item details shows variation type without product type selector" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    get items_add_item_path(step: "item_details")

    assert_response :success
    assert_select "select[name=\"product[variation_type]\"], select[name=\"catalog_item[variation_type]\"]", count: 1
    assert_select "select[name=\"product[product_type]\"], select[name=\"catalog_item[product_type]\"]", count: 0
  end

  test "catalog-linked done after item details saves product only" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    assert_difference -> { Product.count }, 1 do
      assert_no_difference -> { ProductVariant.count } do
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

    product = Product.find_by!(title: "Catalog Only Book")
    assert_redirected_to items_item_path(product_id: product.id)

    follow_redirect!
    assert_match "Product saved", response.body
  end

  test "non-catalog full path creates product and variant without catalog item" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    assert_redirected_to items_add_item_path(step: "item_details")

    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Bag Fee",
        variation_type: "matrix",
        variant1_label: "Denomination",
        variant2_label: "Series",
        list_price_cents: 10,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    post items_add_item_path(step: "selling_setup"), params: {
      product: { default_sub_department_id: @sub_department.id }
    }
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    assert_difference -> { ProductVariant.count }, 1 do
      post items_add_item_path(step: "sellable_sku"), params: {
        product_variant: {
          sub_department_id: @sub_department.id,
          selling_price_cents: 10,
          attribute1_value: "25",
          attribute2_value: "2024"
        }
      }
    end

    product = Product.find_by!(title: "Bag Fee")
    assert_nil product.catalog_item_id
    assert_equal "matrix", product.variation_type
    assert_equal "standard_physical", product.product_variants.first.inventory_behavior
    assert_redirected_to items_item_path(product_id: product.id)
  end

  test "non-catalog service save product only completes without variant" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }

    assert_difference -> { Product.count }, 1 do
      assert_no_difference -> { ProductVariant.count } do
        post items_add_item_path(step: "item_details"), params: {
          catalog_item: {
            staff_item_kind: "service",
            title: "Done Product",
            list_price_cents: 0,
            default_sub_department_id: @sub_department.id
          },
          commit: "Save Product Only"
        }
      end
    end

    product = Product.find_by!(title: "Done Product")
    assert_equal "service", product.product_type
    assert_redirected_to items_item_path(product_id: product.id)

    follow_redirect!
    assert_match "Done Product", response.body
    assert_match "No sellable SKUs yet", response.body
  end

  test "service primary save creates default variant" do
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "service",
        title: "Gift Wrap",
        list_price_cents: 500,
        default_sub_department_id: @sub_department.id
      }
    }

    product = Product.find_by!(title: "Gift Wrap")
    assert_redirected_to items_item_path(product_id: product.id)
    assert_equal 1, product.product_variants.count
    variant = product.product_variants.first
    assert_equal 500, variant.selling_price_cents
    assert_equal @sub_department.id, variant.sub_department_id
    assert variant.active?
  end

  test "create sku and add another keeps wizard on sellable sku step" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Multi Variant",
        variation_type: "conditional",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }
    post items_add_item_path(step: "selling_setup"), params: {
      product: { default_sub_department_id: @sub_department.id }
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
        product_variant: { condition_id: used.id, sub_department_id: @sub_department.id, selling_price_cents: 900 },
        commit: "Create SKU"
      }
    end

    product = Product.find_by!(title: "Multi Variant")
    assert_equal 2, product.product_variants.count
  end

  test "add item sellable sku honors non-inventory tracking selection" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Non-Inventory Physical",
        variation_type: "standard",
        list_price_cents: 1500,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }
    post items_add_item_path(step: "selling_setup"), params: {
      product: { default_sub_department_id: @sub_department.id }
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
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Priced Product",
        variation_type: "standard",
        list_price_cents: 2499,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }
    post items_add_item_path(step: "selling_setup"), params: {
      product: { default_sub_department_id: @sub_department.id }
    }

    get items_add_item_path(step: "sellable_sku")
    assert_response :success
    assert_includes response.body, 'value="2499"'
    assert_includes response.body, "Selling price"
    assert_not_includes response.body, 'name="product_variant[sku]"'
  end

  test "sellable sku step defaults conditional price and sku for new condition" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Conditional Product",
        variation_type: "conditional",
        list_price_cents: 2000,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }
    post items_add_item_path(step: "selling_setup"), params: {
      product: { default_sub_department_id: @sub_department.id }
    }

    get items_add_item_path(step: "sellable_sku")
    assert_response :success
    assert_includes response.body, 'value="2000"'
    assert_includes response.body, 'data-controller="variant-preview"'
    assert_not_includes response.body, 'name="product_variant[sku]"'
    assert_not_includes response.body, 'data-variant-preview-target="skuPreview"'
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
    assert_redirected_to items_add_item_path(step: "item_details")
  end

  test "non-catalog metadata_sections works without catalog item create permission" do
    delete logout_path
    user = create_user!(username: "ncmeta", password: "Password123!")
    grant_permission!(user, "items.access")
    grant_permission!(user, "items.products.create")
    assign_workstation!(@workstation, cookies)
    post login_path, params: { username: "ncmeta", password: "Password123!" }

    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }

    get items_add_item_metadata_sections_path, params: {
      catalog_item: { staff_item_kind: "service" }
    }, headers: { "Turbo-Frame" => "product_metadata_sections" }

    assert_response :success
    assert_includes response.body, "Subdepartment"
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
      commit: nil
    }

    product = Product.find_by!(title: "Invalid ISBN Book")
    assert_equal "9780123456780", product.sku
    assert_equal "9780123456780", product.primary_identifier.normalized_identifier

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Identifier saved with warning"
    assert_includes response.body, "Check digit is invalid"
  end

  test "catalog linked item details persists primary product identifier" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        title: "Valid ISBN Book",
        catalog_item_type: "book",
        format_id: @format.id,
        initial_identifier_type: "isbn13",
        initial_identifier_value: "9780306406157"
      },
      commit: nil
    }

    product = Product.find_by!(title: "Valid ISBN Book")
    assert_equal "9780306406157", product.sku
    assert_equal "9780306406157", product.primary_identifier.normalized_identifier
    assert_redirected_to items_add_item_path(step: "sellable_sku")
  end

  test "duplicate primary identifier re-renders item details with warning and preserved fields" do
    existing = create_catalog_item!
    product = create_product!(catalog_item: existing, skip_product_identifier: true)
    ProductIdentifierService.add_identifier!(
      product: product,
      validation_family: "gtin",
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
        commit: nil
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "already assigned"
    assert_includes response.body, existing.title
    assert_includes response.body, "Duplicate ISBN Book"
    assert_includes response.body, "Someone New"
    assert_includes response.body, 'value="978-0-306-40615-7"'
  end

  test "product_entry_context returns driver-only visibility payload" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    get items_product_entry_context_path, params: {
      staff_item_kind: "recorded_music",
      digital: "0",
      variation_type: "conditional"
    }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "recorded_music", payload["staff_item_kind"]
    assert_equal false, payload["short_form"]
    assert payload["field_visibility"].key?("genre_scheme_picker")
    assert_equal true, payload["field_visibility"]["genre_scheme_picker"]["visible"]
    assert_equal false, payload["field_visibility"]["bisac_picker"]["visible"]
    assert payload["eligible_formats"].is_a?(Array)
  end

  test "product_entry_context returns short form for service" do
    get items_product_entry_context_path, params: { staff_item_kind: "service" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["short_form"]
    assert_equal true, payload["field_visibility"]["subdepartment"]["visible"]
    assert_equal false, payload["field_visibility"]["format"]["visible"]
  end

  test "metadata_sections returns genre picker for recorded music item kind" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    get items_add_item_metadata_sections_path, params: {
      catalog_item: { staff_item_kind: "recorded_music" }
    }, headers: { "Turbo-Frame" => "product_metadata_sections" }

    assert_response :success
    assert_includes response.body, 'data-product-field-key="genre_scheme_picker"'
    assert_includes response.body, "genre_subjects"
  end

  test "metadata_sections returns short form for service item kind" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    get items_add_item_metadata_sections_path, params: {
      catalog_item: { staff_item_kind: "service" }
    }, headers: { "Turbo-Frame" => "product_metadata_sections" }

    assert_response :success
    assert_includes response.body, 'data-product-field-key="subdepartment"'
    assert_match(/data-product-field-key="format"[^>]*hidden/, response.body)
    assert_includes response.body, "Subdepartment"
  end

  test "item details includes stable product form context wiring" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }
    get items_add_item_path(step: "item_details")

    assert_response :success
    assert_includes response.body, 'data-controller="product-metadata-form"'
    assert_includes response.body, 'data-product-metadata-form-target="staffItemKind"'
    assert_includes response.body, items_product_entry_context_path
    assert_includes response.body, 'data-product-field-key="title"'
    assert_includes response.body, 'data-product-field-key="preferred_vendor"'
    assert_select "select[name=\"catalog_item[preferred_vendor_id]\"]", count: 1
    assert_not_includes response.body, 'data-controller="catalog-item-form product-metadata-form"'
    assert_not_includes response.body, "data-product-metadata-form-preview-url-value"
  end

  test "item details saves preferred vendor on create" do
    vendor = create_vendor!(name: "Add Flow Vendor")

    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "book",
        title: "Preferred Vendor Book",
        format_id: @format.id,
        default_sub_department_id: @sub_department.id,
        preferred_vendor_id: vendor.id,
        list_price_cents: 1500
      }
    }

    product = Product.find_by!(title: "Preferred Vendor Book")
    assert_equal vendor.id, product.preferred_vendor_id
    assert_redirected_to items_add_item_path(step: "sellable_sku")

    get items_add_item_path(step: "sellable_sku")
    assert_response :success
    assert_select "select[name=\"product_variant[preferred_vendor_id]\"]" do
      assert_select "option[value=\"#{vendor.id}\"][selected]", count: 1
    end

    post items_add_item_path(step: "sellable_sku"), params: {
      product_variant: {
        selling_price_cents: 1500,
        sub_department_id: @sub_department.id,
        preferred_vendor_id: vendor.id
      }
    }

    variant = product.product_variants.order(:id).last
    assert_equal vendor.id, variant.preferred_vendor_id

    get items_item_path(product_id: product.id, tab: "item_setup")
    assert_response :success
    assert_includes response.body, "Add Flow Vendor"
    assert_includes response.body, "Preferred vendor"
  end

  test "metadata_sections preserves in-progress section field values from request params" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "catalog_linked" }

    get items_add_item_metadata_sections_path, params: {
      catalog_item: {
        staff_item_kind: "book",
        publisher: "In-Progress Publisher",
        description: "Still typing"
      }
    }, headers: { "Turbo-Frame" => "product_metadata_sections" }

    assert_response :success
    assert_includes response.body, "In-Progress Publisher"
    assert_includes response.body, "Still typing"
  end

  test "selling setup attaches cover image during add item wizard" do
    post items_add_item_path(step: "choose_path"), params: { workflow: "non_catalog" }
    post items_add_item_path(step: "item_details"), params: {
      catalog_item: {
        staff_item_kind: "other",
        title: "Cover Product",
        list_price_cents: 1000,
        default_sub_department_id: @sub_department.id
      },
      commit: nil
    }

    cover = fixture_file_upload("cover.png", "image/png")
    post items_add_item_path(step: "selling_setup"), params: {
      product: {
        default_sub_department_id: @sub_department.id,
        cover_image: cover
      },
      commit: "Done"
    }

    product = Product.find_by!(title: "Cover Product")
    assert product.cover_image.attached?
  end
end
