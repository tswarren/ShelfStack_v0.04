# frozen_string_literal: true

module Seeds
  module Phase5Permissions
    ORDERS_RESOURCES = %w[purchase_requests purchase_orders receipts returns_to_vendor].freeze
    ORDERS_ACTIONS = {
      "purchase_requests" => %w[view create update cancel],
      "purchase_orders" => %w[view create update submit cancel close],
      "receipts" => %w[view create update post cancel],
      "returns_to_vendor" => %w[view create update post cancel]
    }.freeze

    SETUP_RESOURCES = %w[product_vendors product_variant_vendors].freeze
    SETUP_ACTIONS = %w[view create update inactivate reactivate delete].freeze

    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    def self.orders_permissions
      [
        permission_attrs("orders", "access", "Access Orders", "Access the orders workspace")
      ] + ORDERS_RESOURCES.flat_map do |resource|
        ORDERS_ACTIONS[resource].map do |action|
          permission_attrs(
            "orders",
            "#{resource}.#{action}",
            "#{action.capitalize} #{resource.tr('_', ' ').titleize}",
            "#{action.capitalize} #{resource.tr('_', ' ')}"
          )
        end
      end
    end

    def self.setup_sourcing_permissions
      SETUP_RESOURCES.flat_map do |resource|
        SETUP_ACTIONS.map do |action|
          permission_attrs(
            "setup",
            "#{resource}.#{action}",
            "#{action.capitalize} #{resource.tr('_', ' ').titleize}",
            "#{action.capitalize} #{resource.tr('_', ' ')}"
          )
        end
      end
    end

    PERMISSIONS = (orders_permissions + setup_sourcing_permissions).freeze

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
    end
  end
end
