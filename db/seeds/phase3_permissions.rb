# frozen_string_literal: true

module Seeds
  module Phase3Permissions
    ITEMS_RESOURCES = %w[catalog_items products product_variants].freeze
    SETUP_CATALOG_RESOURCES = %w[formats product_conditions display_locations store_display_locations vendors].freeze
    ACTIONS = %w[view create update inactivate reactivate delete].freeze

    LEGACY_CATALOG_RESOURCES = %w[formats catalog_items].freeze
    LEGACY_PRODUCTS_RESOURCES = %w[products product_conditions product_variants].freeze

    ACCESS_PERMISSIONS = [
      { key: "items.access", group: "items", name: "Access Items", description: "Access the items workspace" }
    ].freeze

    LEGACY_ACCESS_PERMISSIONS = %w[catalog.access products.access].freeze

    DEPRECATED_KEYS = (
      LEGACY_ACCESS_PERMISSIONS +
      LEGACY_CATALOG_RESOURCES.flat_map { |resource| ACTIONS.map { |action| "catalog.#{resource}.#{action}" } } +
      LEGACY_PRODUCTS_RESOURCES.flat_map { |resource| ACTIONS.map { |action| "products.#{resource}.#{action}" } }
    ).freeze

    def self.permission_attrs(group, resource, action)
      {
        key: "#{group}.#{resource}.#{action}",
        group: group,
        name: "#{action.capitalize} #{resource.tr('_', ' ').titleize}",
        description: "#{action.capitalize} #{resource.tr('_', ' ')}"
      }
    end

    def self.items_permissions
      ITEMS_RESOURCES.flat_map { |resource| ACTIONS.map { |action| permission_attrs("items", resource, action) } }
    end

    def self.setup_catalog_permissions
      SETUP_CATALOG_RESOURCES.flat_map { |resource| ACTIONS.map { |action| permission_attrs("setup", resource, action) } }
    end

    PERMISSIONS = (
      ACCESS_PERMISSIONS +
      items_permissions +
      setup_catalog_permissions
    ).freeze

    def self.seed!
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(permission_key: attrs[:key]).tap do |permission|
          permission.permission_group = attrs[:group]
          permission.name = attrs[:name]
          permission.description = attrs[:description]
          permission.active = true
          permission.save!
        end
      end

      Permission.where(permission_key: DEPRECATED_KEYS).find_each do |permission|
        permission.update!(active: false)
      end
    end
  end
end
