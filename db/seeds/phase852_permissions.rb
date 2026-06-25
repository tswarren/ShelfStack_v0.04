# frozen_string_literal: true

module Seeds
  module Phase852Permissions
    POS_EXEMPTION_ACTIONS = %w[apply void].freeze
    POS_OVERRIDE_ACTIONS = %w[line.apply line.void].freeze
    SETUP_RESOURCES = %w[tax_exception_reasons].freeze
    SETUP_ACTIONS = %w[view create update inactivate].freeze

    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    def self.resource_permissions(group, resource, actions, label)
      actions.map do |action|
        permission_attrs(
          group,
          "#{resource}.#{action}",
          "#{action.tr('.', ' ').split.map(&:capitalize).join(' ')} #{label}",
          "#{action.tr('.', ' ')} #{label.downcase}"
        )
      end
    end

    def self.permissions
      resource_permissions("pos", "tax_exemptions", POS_EXEMPTION_ACTIONS, "POS tax exemptions") +
        POS_OVERRIDE_ACTIONS.map do |action|
          permission_attrs(
            "pos",
            "tax_overrides.#{action}",
            "#{action.tr('.', ' ').split.map(&:capitalize).join(' ')} POS line tax overrides",
            "#{action.tr('.', ' ')} POS line tax overrides"
          )
        end +
        SETUP_RESOURCES.flat_map do |resource|
          resource_permissions("setup", resource, SETUP_ACTIONS, resource.tr("_", " "))
        end
    end

    PERMISSIONS = permissions.freeze

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
