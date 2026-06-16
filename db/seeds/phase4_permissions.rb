# frozen_string_literal: true

module Seeds
  module Phase4Permissions
    INVENTORY_ACTIONS = {
      "inventory" => %w[access balances.view adjustments.view adjustments.create adjustments.post adjustments.cancel ledger.view negative_exceptions.view enterprise.view admin.rebuild_balances]
    }.freeze

    SETUP_RESOURCES = %w[inventory_reason_codes inventory_locations].freeze
    SETUP_ACTIONS = %w[view create update inactivate reactivate delete].freeze

    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    def self.inventory_permissions
      [
        permission_attrs("inventory", "access", "Access Inventory", "Access the inventory workspace"),
        permission_attrs("inventory", "balances.view", "View Inventory Balances", "View store inventory balances"),
        permission_attrs("inventory", "adjustments.view", "View Inventory Adjustments", "View inventory adjustments"),
        permission_attrs("inventory", "adjustments.create", "Create Inventory Adjustments", "Create and edit draft inventory adjustments"),
        permission_attrs("inventory", "adjustments.post", "Post Inventory Adjustments", "Post inventory adjustments"),
        permission_attrs("inventory", "adjustments.cancel", "Cancel Inventory Adjustments", "Cancel draft inventory adjustments"),
        permission_attrs("inventory", "ledger.view", "View Inventory Ledger", "View inventory ledger history"),
        permission_attrs("inventory", "negative_exceptions.view", "View Negative Inventory", "View negative on-hand exceptions"),
        permission_attrs("inventory", "enterprise.view", "View Enterprise Inventory", "View enterprise inventory rollup"),
        permission_attrs("inventory", "admin.rebuild_balances", "Rebuild Inventory Balances", "Rebuild inventory balances from ledger")
      ]
    end

    def self.setup_inventory_permissions
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

    PERMISSIONS = (inventory_permissions + setup_inventory_permissions).freeze

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
