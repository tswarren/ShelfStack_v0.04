# frozen_string_literal: true

module Seeds
  module Phase3CatalogProducts
    FORMATS = [
      { format_key: "hardcover", name: "Hardcover", short_name: "Hardcover", code: "HC", virtual: false },
      { format_key: "trade_paperback", name: "Trade Paperback", short_name: "Trade PB", code: "TP", virtual: false },
      { format_key: "mass_market_paperback", name: "Mass Market Paperback", short_name: "Mass Market", code: "MM", virtual: false },
      { format_key: "calendar", name: "Calendar", short_name: "Calendar", code: "CAL", virtual: false },
      { format_key: "magazine", name: "Magazine", short_name: "Magazine", code: "MAG", virtual: false },
      { format_key: "compact_disc", name: "Compact Disc", short_name: "CD", code: "CD", virtual: false },
      { format_key: "dvd", name: "DVD", short_name: "DVD", code: "DVD", virtual: false },
      { format_key: "ebook", name: "eBook", short_name: "eBook", code: "EBK", virtual: true },
      { format_key: "audiobook_digital", name: "Digital Audiobook", short_name: "Digital Audio", code: "DAB", virtual: true },
      { format_key: "sideline", name: "Sideline", short_name: "Sideline", code: "SIDE", virtual: false }
    ].freeze

    PRODUCT_CONDITIONS = [
      { condition_key: "new", name: "New", short_name: "New", sku_component: nil, sort_order: 0, new_condition: true, default_list_price_factor_bps: 10_000 },
      { condition_key: "signed_copy", name: "Signed Copy", short_name: "Signed", sku_component: "SG", sort_order: 1, new_condition: true, default_list_price_factor_bps: 10_000 },
      { condition_key: "special_edition", name: "Special Edition", short_name: "Special Edition", sku_component: "SP", sort_order: 2, new_condition: true, default_list_price_factor_bps: 10_000 },
      { condition_key: "used_like_new", name: "Used - Like New", short_name: "Like New", sku_component: "UN", sort_order: 11, new_condition: false, default_list_price_factor_bps: 9000 },
      { condition_key: "used_very_fine", name: "Used - Very Fine", short_name: "Very Fine", sku_component: "UV", sort_order: 12, new_condition: false, default_list_price_factor_bps: 7000 },
      { condition_key: "used_fine", name: "Used - Fine", short_name: "Fine", sku_component: "UF", sort_order: 13, new_condition: false, default_list_price_factor_bps: 6000 },
      { condition_key: "used_good", name: "Used - Good", short_name: "Good", sku_component: "UG", sort_order: 14, new_condition: false, default_list_price_factor_bps: 5000 },
      { condition_key: "used_poor", name: "Used - Poor", short_name: "Poor", sku_component: "UP", sort_order: 15, new_condition: false, default_list_price_factor_bps: 3000 },
      { condition_key: "used_ex_library", name: "Used - Ex-Library", short_name: "Ex-Library", sku_component: "UX", sort_order: 16, new_condition: false, default_list_price_factor_bps: 4000 },
      { condition_key: "used_book_club", name: "Used - Book Club", short_name: "Book Club Edition", sku_component: "UB", sort_order: 17, new_condition: false, default_list_price_factor_bps: 2500 },
      { condition_key: "remainder", name: "Remainder", short_name: "Remainder", sku_component: "RM", sort_order: 21, new_condition: true, default_list_price_factor_bps: 10_000 }
    ].freeze

    DISPLAY_LOCATIONS = [].freeze

    def self.seed_display_locations!
      Seeds::Phase3bReferenceTrees.import_display_locations! if DisplayLocation.none?
    end

    VENDORS = [
      { name: "Ingram" },
      { name: "Local Vendor" },
      { name: "Direct Publisher" }
    ].freeze

    def self.seed!
      seed_formats!
      seed_product_conditions!
      seed_vendors!
    end

    def self.seed_formats!
      FORMATS.each do |attrs|
        Format.find_or_initialize_by(format_key: attrs[:format_key]).tap do |format|
          format.assign_attributes(attrs.merge(active: true))
          format.save!
        end
      end
    end

    def self.seed_product_conditions!
      PRODUCT_CONDITIONS.each do |attrs|
        ProductCondition.find_or_initialize_by(condition_key: attrs[:condition_key]).tap do |condition|
          condition.assign_attributes(attrs.merge(active: true))
          condition.save!
        end
      end
    end

    def self.seed_vendors!
      VENDORS.each do |attrs|
        Vendor.find_or_initialize_by(name: attrs[:name]).tap do |vendor|
          vendor.assign_attributes(attrs.merge(active: true))
          vendor.save!
        end
      end
    end

    def self.seed_demo_catalog_and_products!
      hardcover = Format.find_by!(format_key: "hardcover")
      sideline = Format.find_by!(format_key: "sideline")
      trade_sub_department = SubDepartment.find_by!(sub_department_key: "general_trade")
      gift_sub_department = SubDepartment.find_by!(sub_department_key: "other")
      new_condition = ProductCondition.find_by!(condition_key: "new")
      featured_display = DisplayLocation.find_by!(short_name: "bestsellers")
      fiction_store_category = CategoryScheme.find_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
                                            .category_nodes.find_by!(node_key: "fiction")
      sideline_store_category = CategoryScheme.find_by!(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
                                              .category_nodes.find_by!(node_key: "sideline")

      # Product-first demo items (v0.04-1). Legacy catalog rows are not created here.
      product = Product.find_or_initialize_by(sku: "9780123456786")
      if product.new_record?
        product.assign_attributes(
          title: "The Hobbit",
          name: "The Hobbit",
          catalog_item_type: "book",
          format: hardcover,
          creators: "Tolkien, J.R.R. [author]",
          publisher: "Houghton Mifflin",
          publication_status: "active",
          store_category: fiction_store_category,
          product_type: "physical",
          variation_type: "standard",
          list_price_cents: 1899,
          default_display_location: featured_display,
          active: true
        )
        product.save!
        ProductVariant.find_or_create_by!(product: product, sku: product.sku) do |variant|
          variant.assign_attributes(
            name: ProductNameRenderer.variant_name(
              ProductVariant.new(product: product, condition: new_condition, sub_department: trade_sub_department)
            ),
            condition: new_condition,
            sub_department: trade_sub_department,
            selling_price_cents: 1899,
            inventory_behavior: "standard_physical",
            active: true
          )
        end
      end

      gift_product = Product.find_or_initialize_by(sku: "GIFT-CARD-25")
      if gift_product.new_record?
        gift_product.assign_attributes(
          title: "Gift Card $25",
          name: "Gift Card $25",
          catalog_item_type: "gift",
          publication_status: "active",
          product_type: "financial",
          variation_type: "standard",
          list_price_cents: 2500,
          active: true
        )
        gift_product.save!
        ProductVariant.find_or_create_by!(product: gift_product, sku: gift_product.sku) do |variant|
          variant.assign_attributes(
            name: gift_product.name,
            condition: new_condition,
            sub_department: gift_sub_department,
            selling_price_cents: 2500,
            inventory_behavior: "pure_financial",
            active: true
          )
        end
      end

      sideline_product = Product.find_or_initialize_by(sku: "LOCAL-TOTE-001")
      if sideline_product.new_record?
        sideline_product.assign_attributes(
          title: "Bookstore Tote Bag",
          name: "Bookstore Tote Bag",
          catalog_item_type: "sideline",
          format: sideline,
          publication_status: "active",
          store_category: sideline_store_category,
          product_type: "physical",
          variation_type: "standard",
          list_price_cents: 1499,
          default_sub_department: gift_sub_department,
          active: true
        )
        sideline_product.save!
      end
    end

    def self.copy_catalog_metadata_to_product!(product, catalog_item)
      product.assign_attributes(
        catalog_item_type: catalog_item.catalog_item_type,
        title: catalog_item.title,
        creators: catalog_item.creators,
        creator_details: catalog_item.creator_details,
        publisher: catalog_item.publisher,
        publisher_details: catalog_item.publisher_details,
        publication_date: catalog_item.publication_date,
        publication_status: catalog_item.publication_status,
        series_name: catalog_item.series_name,
        series_enumeration: catalog_item.series_enumeration,
        series_data: catalog_item.series_data,
        format_id: catalog_item.format_id,
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
        store_category_id: catalog_item.store_category_id,
        source: catalog_item.source,
        needs_review: catalog_item.needs_review
      )
      product.save!
    end
  end
end
