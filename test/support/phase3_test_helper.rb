# frozen_string_literal: true

module Phase3TestHelper
  def create_format!(**attrs)
    Format.create!({
      format_key: "format_#{SecureRandom.hex(4)}",
      name: "Hardcover",
      short_name: "Hardcover",
      active: true
    }.merge(attrs))
  end

  def create_catalog_item!(format: nil, **attrs)
    format ||= create_format!
    item = CatalogItem.create!({
      catalog_item_type: "book",
      title: "Test Book",
      publication_status: "active",
      format: format,
      active: true
    }.merge(attrs))

    if item.catalog_item_identifiers.active_records.none?
      CatalogIdentifierService.generate_local!(catalog_item: item)
    end

    item.reload
  end

  def store_category_node_for_tests
    @store_category_node_for_tests ||= begin
      scheme = CategoryScheme.find_or_create_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY) do |record|
        record.name = "Store Categories"
        record.purpose = CategoryNode::STORE_CATEGORIES_SCHEME_KEY
        record.active = true
      end
      scheme.category_nodes.find_or_create_by!(node_key: "fiction") do |node|
        node.name = "Fiction"
        node.sort_order = 1
        node.active = true
      end
    end
  end

  def ensure_test_store_category!(catalog_item)
    return catalog_item if catalog_item.store_category.present?

    catalog_item.update!(store_category: store_category_node_for_tests)
    catalog_item
  end

  def create_product_condition!(**attrs)
    ProductCondition.create!({
      condition_key: "test_new",
      name: "Test New",
      short_name: "Test New",
      sort_order: 99,
      new_condition: true,
      default_list_price_factor_bps: 10_000,
      active: true
    }.merge(attrs))
  end

  def create_display_location!(**attrs)
    DisplayLocation.create!({
      name: "Test Location",
      short_name: "Test Loc #{SecureRandom.hex(2)}",
      sort_order: 0,
      active: true
    }.merge(attrs))
  end

  def create_product!(catalog_item: nil, **attrs)
    catalog_item ||= create_catalog_item!
    ensure_test_store_category!(catalog_item)
    Product.create!({
      catalog_item: catalog_item,
      name: catalog_item.title,
      sku: catalog_item.primary_identifier.normalized_identifier,
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 1000,
      active: true
    }.merge(attrs))
  end

  def create_product_variant!(product: nil, sub_department: nil, category: nil, condition: nil, **attrs)
    product ||= create_product!
    category ||= create_category! unless sub_department
    sub_department ||= category&.sub_department
    if sub_department.blank?
      department = category&.department || create_department!(
        department_number: format("%03d", SecureRandom.random_number(900) + 100),
        name: "Test Department #{SecureRandom.hex(2)}",
        short_name: "TD#{SecureRandom.hex(2)}"
      )
      sub_department = SubDepartment.create!(
        sub_department_key: "test_sd_#{SecureRandom.hex(3)}",
        name: "Test Subdepartment #{SecureRandom.hex(2)}",
        short_name: "TSD #{SecureRandom.hex(1)}",
        department: department,
        default_tax_category: category.default_tax_category,
        active: true
      )
      category.update!(sub_department: sub_department, department: sub_department.department)
    end
    condition ||= ProductCondition.find_by(condition_key: "new") || create_product_condition!(condition_key: "new", sku_component: nil)
    ProductVariant.create!({
      product: product,
      sub_department: sub_department,
      condition: condition,
      name: product.name,
      sku: product.sku,
      selling_price_cents: 1000,
      inventory_behavior: "standard_physical",
      active: true
    }.merge(attrs))
  end

  def create_vendor!(**attrs)
    Vendor.create!({
      name: "Test Vendor #{SecureRandom.hex(2)}",
      active: true
    }.merge(attrs))
  end

  def seed_phase3_reference_data!
    require_relative "../../db/seeds/phase3_catalog_products"
    Seeds::Phase3CatalogProducts.seed_formats!
    Seeds::Phase3CatalogProducts.seed_product_conditions!
  end

  def grant_all_phase3_permissions!(user, store: nil)
    Seeds::Phase3Permissions.seed!
    Seeds::Phase3Permissions::PERMISSIONS.each do |permission|
      grant_permission!(user, permission[:key], store: store)
    end
  end
end
