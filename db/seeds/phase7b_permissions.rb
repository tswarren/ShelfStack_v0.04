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

    def self.pos_tender_perms
      [
        permission_attrs("pos.tenders", "store_credit", "Redeem store credit at POS", "Redeem store credit as POS tender"),
        permission_attrs("pos.tenders", "gift_card", "Redeem gift card at POS", "Redeem gift card stored value as POS tender"),
        permission_attrs("pos.refunds", "store_credit", "Issue store credit from POS", "Issue store credit from POS returns and exchanges"),
        permission_attrs("pos.gift_cards", "issue", "Sell gift cards at POS", "Issue or reload gift card stored value from POS sales")
      ]
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

      account_perms + identifier_perms + operation_perms + setup_perms + pos_tender_perms + [
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

      grant_pos_stored_value_to_roles!
    end

    POS_STORED_VALUE_ROLE_KEYS = %w[pos_cashier pos_lead pos_manager].freeze
    POS_STORED_VALUE_PERMISSION_KEYS = %w[
      pos.tenders.store_credit
      pos.tenders.gift_card
      pos.refunds.store_credit
      pos.gift_cards.issue
      stored_value.accounts.create
      stored_value.identifiers.create
    ].freeze

    def self.grant_pos_stored_value_to_roles!
      POS_STORED_VALUE_ROLE_KEYS.each do |role_key|
        role = Role.find_by(role_key: role_key)
        next if role.blank?

        POS_STORED_VALUE_PERMISSION_KEYS.each do |permission_key|
          permission = Permission.find_by(permission_key: permission_key)
          next if permission.blank?

          role.grant_permission!(permission)
        end
      end
    end
  end
end
