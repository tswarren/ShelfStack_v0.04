# frozen_string_literal: true

module Phase3TestHelper
  def create_store_for_phase3!
    @phase3_store ||= Store.find_by(store_number: "001") || Store.create!(
      store_number: "001",
      name: "Test Store",
      country_code: "US",
      time_zone: "America/New_York",
      active: true
    )
  end

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
    suffix = SecureRandom.hex(3)
    ProductCondition.create!({
      condition_key: "test_new_#{suffix}",
      name: "Test New #{suffix}",
      short_name: "TN#{suffix}",
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

  def catalog_metadata_attrs_for(catalog_item)
    {
      title: catalog_item.title,
      catalog_item_type: catalog_item.catalog_item_type,
      creators: catalog_item.creators,
      creator_details: catalog_item.creator_details,
      publisher: catalog_item.publisher,
      publisher_details: catalog_item.publisher_details,
      publication_date: catalog_item.publication_date,
      publication_status: catalog_item.publication_status,
      series_name: catalog_item.series_name,
      series_enumeration: catalog_item.series_enumeration,
      series_data: catalog_item.series_data,
      format: catalog_item.format,
      edition_statement: catalog_item.edition_statement,
      language_code: catalog_item.language_code,
      description: catalog_item.description,
      year: catalog_item.year,
      bisac_subjects: catalog_item.bisac_subjects,
      bisac_subject_data: catalog_item.bisac_subject_data,
      genres: catalog_item.genres,
      genre_data: catalog_item.genre_data,
      themes: catalog_item.themes,
      theme_data: catalog_item.theme_data,
      target_audiences: catalog_item.target_audiences,
      target_audience_data: catalog_item.target_audience_data,
      access_restrictions: catalog_item.access_restrictions,
      access_restriction_data: catalog_item.access_restriction_data,
      publication_frequency: catalog_item.publication_frequency,
      digital: catalog_item.digital,
      large_print: catalog_item.large_print,
      page_count: catalog_item.page_count,
      duration_minutes: catalog_item.duration_minutes,
      height: catalog_item.height,
      width: catalog_item.width,
      depth: catalog_item.depth,
      dimension_units: catalog_item.dimension_units,
      weight: catalog_item.weight,
      weight_units: catalog_item.weight_units,
      store_category: catalog_item.store_category,
      source: catalog_item.source,
      needs_review: catalog_item.needs_review
    }
  end

  def create_legacy_catalog_linked_product!(catalog_item: nil, **attrs)
    catalog_item ||= create_catalog_item! unless attrs.key?(:title)
    ensure_test_store_category!(catalog_item)
    Product.create!({
      catalog_item: catalog_item,
      name: catalog_item.title,
      sku: catalog_item.primary_identifier.normalized_identifier,
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 1000,
      active: true
    }.merge(catalog_metadata_attrs_for(catalog_item)).merge(attrs))
  end

  def create_product!(**attrs)
    if attrs.key?(:catalog_item) && attrs[:catalog_item].present?
      return create_legacy_catalog_linked_product!(**attrs)
    end

    attrs = attrs.dup
    attrs.delete(:catalog_item)
    format = attrs.delete(:format) || create_format!
    title = attrs[:title] || attrs[:name] || "Test Product"
    sku = attrs[:sku] || "P#{SecureRandom.hex(4).upcase}"
    Product.create!({
      title: title,
      catalog_item_type: attrs[:catalog_item_type] || "book",
      format: format,
      publication_status: "active",
      name: title,
      sku: sku,
      product_type: "physical",
      variation_type: "standard",
      list_price_cents: 1000,
      active: true
    }.merge(attrs))
  end

  def create_product_variant!(product: nil, legacy_catalog_linked: false, sub_department: nil, condition: nil, **attrs)
    product ||= legacy_catalog_linked ? create_legacy_catalog_linked_product! : create_product!
    unless sub_department
      department = create_department!(
        name: "Test Department #{SecureRandom.hex(2)}",
        short_name: "TD#{SecureRandom.hex(2)}"
      )
      sub_department = SubDepartment.create!(
        sub_department_key: "test_sd_#{SecureRandom.hex(3)}",
        name: "Test Subdepartment #{SecureRandom.hex(2)}",
        short_name: "TSD #{SecureRandom.hex(1)}",
        department: department,
        default_tax_category: create_tax_category!,
        default_pricing_model: "trade_discount",
        active: true
      )
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
