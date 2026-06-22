# frozen_string_literal: true

module Seeds
  module Phase7aPermissions
    CUSTOMER_ACTIONS = %w[create update inactivate reactivate].freeze
    REQUEST_ACTIONS = %w[create update cancel mark_unfillable contact].freeze
    SPECIAL_ORDER_ACTIONS = %w[create approve attach_to_po cancel].freeze
    RESERVATION_ACTIONS = %w[create release override expire].freeze
    POS_EXTRA_ACTIONS = %w[fulfill_customer_reservation sell_reserved_stock_override].freeze

    def self.permission_attrs(group, key_suffix, name, description)
      {
        key: "#{group}.#{key_suffix}",
        group: group,
        name: name,
        description: description
      }
    end

    def self.permissions
      [
        permission_attrs("customers", "access", "Access Customers", "Access the customers workspace"),
        permission_attrs("customer_requests", "access", "Access Customer Requests", "Access customer requests")
      ] +
        CUSTOMER_ACTIONS.map do |action|
          permission_attrs("customers", action, "#{action.capitalize} customers", "#{action} customers")
        end +
        REQUEST_ACTIONS.map do |action|
          permission_attrs("customer_requests", action, "#{action.capitalize} customer requests", "#{action} customer requests")
        end +
        SPECIAL_ORDER_ACTIONS.map do |action|
          permission_attrs("special_orders", action, "#{action.tr('_', ' ').capitalize} special orders", "#{action} special orders")
        end +
        RESERVATION_ACTIONS.map do |action|
          permission_attrs("inventory_reservations", action, "#{action.capitalize} inventory reservations", "#{action} inventory reservations")
        end +
        POS_EXTRA_ACTIONS.map do |action|
          permission_attrs(
            "pos",
            action,
            action.tr("_", " ").split.map(&:capitalize).join(" "),
            action.tr("_", " ")
          )
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
