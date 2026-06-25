# frozen_string_literal: true

module Seeds
  module Phase6Roles
    ROLE_BUNDLES = {
      "pos_cashier" => {
        name: "POS Cashier",
        description: "Standard register operations",
        permissions: %w[
          pos.access
          pos.transactions.view pos.transactions.create pos.transactions.update
          pos.transactions.complete pos.transactions.suspend pos.transactions.resume
          pos.transactions.cancel
          pos.lines.add pos.lines.update pos.lines.remove
          pos.tenders.cash pos.tenders.card pos.tenders.check
          pos.tenders.store_credit pos.tenders.gift_card
          pos.refunds.store_credit
          pos.register_sessions.view pos.register_sessions.open pos.register_sessions.close
          pos.cash_movements.view pos.cash_movements.create
          pos.receipts.view pos.receipts.print
          pos.reports.view pos.reports.drawer pos.reports.sales
          pos.returns.receipted pos.returns.partial
          pos.discounts.line.apply pos.discounts.transaction.apply
        ]
      },
      "pos_lead" => {
        name: "POS Lead Cashier",
        description: "Lead cashier with returns and resume-other",
        permissions: %w[
          pos.access
          pos.transactions.view pos.transactions.create pos.transactions.update
          pos.transactions.complete pos.transactions.suspend pos.transactions.resume
          pos.transactions.resume.other_cashier pos.transactions.cancel
          pos.lines.add pos.lines.add.open_ring pos.lines.update pos.lines.remove
          pos.tenders.cash pos.tenders.card pos.tenders.check
          pos.tenders.store_credit pos.tenders.gift_card
          pos.refunds.store_credit pos.tenders.refund
          pos.register_sessions.view pos.register_sessions.open pos.register_sessions.close
          pos.cash_movements.view pos.cash_movements.create
          pos.receipts.view pos.receipts.print
          pos.reports.view pos.reports.drawer pos.reports.sales pos.reports.returns pos.reports.summary pos.reports.register_summary
          pos.returns.receipted pos.returns.partial pos.returns.no_receipt
          pos.lines.sell_inactive
          pos.discounts.line.apply pos.discounts.transaction.apply pos.discounts.void
        ]
      },
      "pos_manager" => {
        name: "POS Manager",
        description: "Full POS operations including authorizations and exports",
        permissions: (
          Seeds::Phase6Permissions::PERMISSIONS.map { |attrs| attrs[:key] } +
          Seeds::Phase85Permissions::PERMISSIONS.map { |attrs| attrs[:key] } +
          %w[pos.refunds.store_credit]
        ).uniq
      }
    }.freeze

    def self.seed!
      ROLE_BUNDLES.each do |role_key, config|
        role = Role.find_or_initialize_by(role_key: role_key)
        role.assign_attributes(
          name: config[:name],
          description: config[:description],
          system_role: false,
          active: true
        )
        role.save!

        config[:permissions].each do |permission_key|
          permission = Permission.find_by(permission_key: permission_key)
          next if permission.blank?

          role.grant_permission!(permission)
        end
      end
    end
  end
end
