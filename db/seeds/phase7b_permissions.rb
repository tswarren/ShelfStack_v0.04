# frozen_string_literal: true

module Seeds
  module Phase7bPermissions
    ACCOUNT_ACTIONS = %w[view create update suspend close reactivate].freeze
    IDENTIFIER_ACTIONS = %w[create replace deactivate view_full].freeze
    OPERATION_ACTIONS = %w[issue adjust void transfer].freeze
    SETUP_ACTIONS = %w[view create update inactivate reactivate delete].freeze

    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    def self.stored_value_permissions
      account_perms = ACCOUNT_ACTIONS.map do |action|
        permission_attrs(
          "stored_value.accounts",
          action,
          "#{action.capitalize} stored value accounts",
          "#{action} stored value accounts"
        )
      end

      identifier_perms = IDENTIFIER_ACTIONS.map do |action|
        permission_attrs(
          "stored_value.identifiers",
          action,
          "#{action.capitalize} stored value identifiers",
          "#{action} stored value identifiers"
        )
      end

      operation_perms = OPERATION_ACTIONS.map do |action|
        permission_attrs(
          "stored_value",
          action,
          "#{action.capitalize} stored value",
          "#{action} stored value balances"
        )
      end

      setup_perms = SETUP_ACTIONS.map do |action|
        permission_attrs(
          "setup",
          "stored_value_reason_codes.#{action}",
          "#{action.capitalize} stored value reason codes",
          "#{action} stored value reason codes"
        )
      end

      account_perms + identifier_perms + operation_perms + setup_perms + [
        permission_attrs("stored_value.ledger", "view", "View stored value ledger", "View stored value ledger history"),
        permission_attrs("stored_value.reports", "view", "View stored value reports", "View stored value liability reports"),
        permission_attrs(
          "stored_value.admin",
          "rebuild_balances",
          "Rebuild stored value balances",
          "Rebuild stored value balances from ledger"
        )
      ]
    end

    PERMISSIONS = stored_value_permissions.freeze

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
