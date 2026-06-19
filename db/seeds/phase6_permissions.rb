# frozen_string_literal: true

module Seeds
  module Phase6Permissions
    TRANSACTION_ACTIONS = %w[
      view create update complete suspend resume resume.other_cashier void cancel
    ].freeze
    LINE_ACTIONS = %w[add add.open_ring update remove sell_inactive].freeze
    DISCOUNT_ACTIONS = %w[line.apply transaction.apply override_limit].freeze
    RETURN_ACTIONS = %w[
      receipted no_receipt partial disposition.override open_ring cash_refund.over_threshold
    ].freeze
    TENDER_ACTIONS = %w[cash card check gift_card store_credit refund].freeze
    REGISTER_ACTIONS = %w[view open close force_close reconcile].freeze
    CASH_ACTIONS = %w[view create large_amount].freeze
    AUTHORIZATION_ACTIONS = %w[grant self_grant].freeze
    RECEIPT_ACTIONS = %w[view print email].freeze
    REPORT_ACTIONS = %w[view drawer sales returns export].freeze

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
      [
        permission_attrs("pos", "access", "Access POS", "Access the POS workspace")
      ] + resource_permissions("pos", "transactions", TRANSACTION_ACTIONS, "POS transactions") +
        resource_permissions("pos", "lines", LINE_ACTIONS, "POS lines") +
        resource_permissions("pos", "discounts", DISCOUNT_ACTIONS, "POS discounts") +
        resource_permissions("pos", "returns", RETURN_ACTIONS, "POS returns") +
        resource_permissions("pos", "tenders", TENDER_ACTIONS, "POS tenders") +
        resource_permissions("pos", "register_sessions", REGISTER_ACTIONS, "register sessions") +
        resource_permissions("pos", "cash_movements", CASH_ACTIONS, "cash movements") +
        resource_permissions("pos", "authorizations", AUTHORIZATION_ACTIONS, "POS authorizations") +
        resource_permissions("pos", "receipts", RECEIPT_ACTIONS, "POS receipts") +
        resource_permissions("pos", "reports", REPORT_ACTIONS, "POS reports")
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
