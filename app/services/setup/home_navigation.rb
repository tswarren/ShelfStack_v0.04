# frozen_string_literal: true

module Setup
  class HomeNavigation
    include Rails.application.routes.url_helpers

    Link = Data.define(:label, :label_key, :path)
    Section = Data.define(:title, :links)

    SECTIONS = [
      {
        title: "Foundation",
        links: [
          { label: "Users", permission_key: "setup.users.view", path: :users },
          { label: "Roles", permission_key: "setup.roles.view", path: :roles },
          { label: "Permissions", permission_key: "setup.permissions.view", path: :permissions },
          { label: "Stores", permission_key: "setup.stores.view", path: :stores },
          { label: "Workstations", permission_key: "setup.workstations.view", path: :workstations },
          { label: "Audit Events", permission_key: "audit_events.view", path: :audit_events }
        ]
      },
      {
        title: "Classification",
        links: [
          { label: "Departments", permission_key: "setup.departments.view", path: :departments },
          { label: "Subdepartments", permission_key: "setup.sub_departments.view", path: :sub_departments },
          { label: "Store Categories", permission_key: "setup.category_schemes.view", path: :store_category_nodes },
          { label: "Category Schemes", permission_key: "setup.category_schemes.view", path: :category_schemes },
          { label: "BISAC Subjects", permission_key: "setup.bisac_subjects.view", path: :bisac_subjects },
          { label: "Tax Categories", permission_key: "setup.tax_categories.view", path: :tax_categories },
          { label: "Store Tax Rates", permission_key: "setup.store_tax_rates.view", path: :store_tax_rates },
          { label: "Tax Mappings", permission_key: "setup.store_tax_category_rates.view", path: :store_tax_category_rates }
        ]
      },
      {
        title: "Catalog and Items",
        links: [
          { label: "Formats", permission_key: "setup.formats.view", path: :formats },
          { label_key: "product_conditions", permission_key: "setup.product_conditions.view", path: :product_conditions },
          { label_key: "display_locations", permission_key: "setup.display_locations.view", path: :display_locations },
          { label: "Store Display Locations", permission_key: "setup.store_display_locations.view", path: :store_display_locations },
          { label: "Vendors", permission_key: "setup.vendors.view", path: :vendors },
          { label: "Product Vendors", permission_key: "setup.product_vendors.view", path: :product_vendors },
          { label: "Variant Vendors", permission_key: "setup.product_variant_vendors.view", path: :product_variant_vendors },
          { label: "External Data Sources", permission_key: "setup.access", path: :external_data_sources }
        ]
      },
      {
        title: "Inventory",
        links: [
          { label: "Inventory Reason Codes", permission_key: "setup.inventory_reason_codes.view", path: :inventory_reason_codes },
          { label: "Store Inventory Locations", permission_key: "setup.inventory_locations.view", path: :inventory_locations },
          { label: "Stored Value Reason Codes", permission_key: "setup.stored_value_reason_codes.view", path: :stored_value_reason_codes },
          { label: "Discount Reasons", permission_key: "setup.discount_reasons.view", path: :discount_reasons },
          { label: "Tax Exception Reasons", permission_key: "setup.tax_exception_reasons.view", path: :tax_exception_reasons }
        ]
      }
    ].freeze

    def self.sections_for(user:, store:)
      new(user: user, store: store).sections
    end

    def initialize(user:, store:)
      @user = user
      @store = store
    end

    def sections
      SECTIONS.filter_map do |section_definition|
        links = section_definition[:links].filter_map { |link_definition| build_link(link_definition) }
        next if links.empty?

        Section.new(title: section_definition[:title], links: links)
      end
    end

    private

    attr_reader :user, :store

    def build_link(link_definition)
      return unless Authorization.allowed?(user: user, permission_key: link_definition[:permission_key], store: store)

      Link.new(
        label: link_definition[:label],
        label_key: link_definition[:label_key],
        path: resolve_path(link_definition[:path])
      )
    end

    def resolve_path(path_key)
      case path_key
      when :users then setup_users_path
      when :roles then setup_roles_path
      when :permissions then setup_permissions_path
      when :stores then setup_stores_path
      when :workstations then setup_workstations_path
      when :audit_events then setup_audit_events_path
      when :departments then setup_departments_path
      when :sub_departments then setup_sub_departments_path
      when :store_category_nodes then store_category_nodes_path
      when :category_schemes then setup_category_schemes_path
      when :bisac_subjects then setup_bisac_subjects_path
      when :tax_categories then setup_tax_categories_path
      when :store_tax_rates then setup_store_tax_rates_path
      when :store_tax_category_rates then setup_store_tax_category_rates_path
      when :formats then setup_formats_path
      when :product_conditions then setup_product_conditions_path
      when :display_locations then setup_display_locations_path
      when :store_display_locations then setup_store_display_locations_path
      when :vendors then setup_vendors_path
      when :product_vendors then setup_product_vendors_path
      when :product_variant_vendors then setup_product_variant_vendors_path
      when :external_data_sources then setup_external_data_sources_path
      when :inventory_reason_codes then setup_inventory_reason_codes_path
      when :inventory_locations then setup_inventory_locations_path
      when :stored_value_reason_codes then setup_stored_value_reason_codes_path
      when :discount_reasons then setup_discount_reasons_path
      when :tax_exception_reasons then setup_tax_exception_reasons_path
      else
        raise ArgumentError, "Unknown setup home path key: #{path_key.inspect}"
      end
    end

    def store_category_nodes_path
      scheme = CategoryScheme.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      if scheme
        setup_category_scheme_category_nodes_path(scheme)
      else
        setup_category_schemes_path
      end
    end
  end
end
