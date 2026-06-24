# frozen_string_literal: true

module Seeds
  module Phase7cPermissions
    ACTIONS = %w[
      view create update create_intake_item price_override accept reject
      complete pay_cash pay_trade_credit accept_donation cancel void
      trade_credit_slip.print proposal.save proposal.print
      decisions.update decisions.batch_update
    ].freeze

    def self.permission_attrs(key_suffix, name, description)
      {
        key: "buybacks.#{key_suffix}",
        group: "buybacks",
        name: name,
        description: description
      }
    end

    PERMISSIONS = (
      [ permission_attrs("view", "View buybacks", "Access the buybacks workspace") ] +
      [ permission_attrs("reports.view", "View buyback reports", "View buyback operational reports") ] +
      ACTIONS.reject { |a| a == "view" }.map do |action|
        permission_attrs(action, "#{action.tr('_', ' ').capitalize} buybacks", "#{action} buyback sessions")
      end
    ).freeze

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
