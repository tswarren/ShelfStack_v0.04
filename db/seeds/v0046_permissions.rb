# frozen_string_literal: true

module Seeds
  module V0046Permissions
    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    PERMISSIONS = [
      permission_attrs("demand", "access", "Access Demand", "Access the demand workspace"),
      permission_attrs("demand", "create", "Create demand", "Create demand lines"),
      permission_attrs("demand", "update", "Update demand", "Update demand lines"),
      permission_attrs("demand", "cancel", "Cancel demand", "Cancel demand lines"),
      permission_attrs("demand", "expire", "Expire demand", "Manually expire open demand lines"),
      permission_attrs("demand", "match_variant", "Match demand variant", "Match provisional demand to a variant"),
      permission_attrs("stock_considerations", "access", "Access stock considerations", "Access stock consideration queue"),
      permission_attrs("stock_considerations", "create", "Create stock considerations", "Create stock considerations"),
      permission_attrs("stock_considerations", "convert", "Convert stock considerations", "Convert stock considerations to demand"),
      permission_attrs("stock_considerations", "dismiss", "Dismiss stock considerations", "Dismiss stock considerations")
    ].freeze

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
