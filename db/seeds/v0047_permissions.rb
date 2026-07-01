# frozen_string_literal: true

module Seeds
  module V0047Permissions
    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    PERMISSIONS = [
      permission_attrs("demand", "allocations.access", "Access demand allocations", "View demand allocation summaries"),
      permission_attrs("demand", "allocations.create", "Create demand allocations", "Allocate demand from on-hand or inbound PO"),
      permission_attrs("demand", "allocations.release", "Release demand allocations", "Release active demand allocations"),
      permission_attrs("demand", "allocations.cancel", "Cancel demand allocations", "Cancel active demand allocations"),
      permission_attrs("demand", "allocations.expire", "Expire demand allocations", "Expire active demand allocations"),
      permission_attrs("demand", "allocations.fulfill", "Fulfill demand allocations", "Mark demand allocations fulfilled"),
      permission_attrs("demand", "allocations.override_availability", "Override allocation availability", "Allocate on-hand beyond available quantity"),
      permission_attrs("demand", "expire_due", "Expire due demand", "Run expire-due demand processing from admin UI")
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
