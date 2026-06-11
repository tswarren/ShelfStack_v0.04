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

  def create_product_variant!(product: nil, category: nil, condition: nil, **attrs)
    product ||= create_product!
    category ||= create_category!
    condition ||= ProductCondition.find_by(condition_key: "new") || create_product_condition!(condition_key: "new", sku_component: nil)
    ProductVariant.create!({
      product: product,
      category: category,
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
