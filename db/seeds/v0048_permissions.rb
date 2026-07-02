# frozen_string_literal: true

module Seeds
  module V0048Permissions
    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    PERMISSIONS = [
      permission_attrs("sourcing", "access", "Access sourcing workspace", "View sourcing runs and attempts"),
      permission_attrs("sourcing", "runs.create", "Start sourcing runs", "Start vendor sourcing for demand lines"),
      permission_attrs("sourcing", "attempts.create", "Create sourcing attempts", "Create vendor sourcing attempts"),
      permission_attrs("sourcing", "attempts.submit", "Submit sourcing attempts", "Submit vendor sourcing attempts"),
      permission_attrs("sourcing", "responses.record", "Record vendor responses", "Record vendor response quantity splits"),
      permission_attrs("sourcing", "attempts.cascade", "Cascade sourcing attempts", "Cascade unresolved quantity to another vendor"),
      permission_attrs("sourcing", "attempts.cancel", "Cancel sourcing attempts", "Cancel pending or submitted sourcing attempts"),
      permission_attrs("sourcing", "runs.close", "Close sourcing runs", "Close or cancel sourcing runs"),
      permission_attrs("sourcing", "vendor_override", "Manual vendor override", "Override suggested vendor for sourcing attempts")
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
