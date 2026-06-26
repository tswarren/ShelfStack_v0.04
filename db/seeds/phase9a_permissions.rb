# frozen_string_literal: true

module Seeds
  module Phase9aPermissions
    PERMISSION_KEY = "reports.foundation.view"

    def self.permission_attrs
      {
        key: PERMISSION_KEY,
        group: "reports",
        name: "View report foundation shells",
        description: "View Phase 9a sample report shells and shared report layout proofs"
      }
    end

    def self.seed!
      attrs = permission_attrs
      Permission.find_or_initialize_by(permission_key: attrs[:key]).tap do |permission|
        permission.permission_group = attrs[:group]
        permission.name = attrs[:name]
        permission.description = attrs[:description]
        permission.active = true
        permission.save!
      end

      grant_to_pos_manager!
    end

    def self.grant_to_pos_manager!
      role = Role.find_by(role_key: "pos_manager")
      permission = Permission.find_by(permission_key: PERMISSION_KEY)
      return if role.blank? || permission.blank?

      role.grant_permission!(permission)
    end
  end
end
