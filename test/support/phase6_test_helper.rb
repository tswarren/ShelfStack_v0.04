# frozen_string_literal: true

module Phase6TestHelper
  def grant_all_phase6_permissions!(user, store: nil)
    Seeds::Phase6Permissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def open_register_session!(store:, workstation:, user:, business_date: Date.current, opening_cash_cents: 0)
    Pos::RegisterSessionLifecycle.open!(
      store: store,
      workstation: workstation,
      opened_by_user: user,
      business_date: business_date,
      opening_cash_cents: opening_cash_cents
    )
  end

  def create_pos_transaction!(store:, workstation:, user:, attrs: {}, lines: [], tenders: [])
    transaction = PosTransaction.create!({
      store: store,
      workstation: workstation,
      cashier_user: user,
      status: "draft"
    }.merge(attrs))

    lines.each_with_index do |line_attrs, index|
      transaction.pos_transaction_lines.create!({ line_number: index + 1, line_type: "variant" }.merge(line_attrs))
    end

    tenders.each do |tender_attrs|
      transaction.pos_tenders.create!(tender_attrs)
    end

    transaction
  end

  def complete_pos_sale!(transaction:, user:, register_session:, tenders: nil)
    if tenders
      transaction.pos_tenders.destroy_all
      tenders.each { |attrs| transaction.pos_tenders.create!(attrs) }
    end

    Pos::RecalculateTransaction.call!(transaction, business_date: register_session.business_date)
    unless transaction.pos_tenders.exists?
      transaction.pos_tenders.create!(tender_type: "cash", amount_cents: transaction.total_cents)
    end

    Pos::CompleteTransaction.call!(
      transaction: transaction.reload,
      completed_by_user: user,
      register_session: register_session,
      confirmed_inactive: true
    )
  end

  def grant_void_authorization!(transaction:, requested_by:, manager: nil)
    manager ||= create_user!(username: "void-manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: transaction.store)

    Pos::AuthorizationRequest.grant!(
      authorization_type: "void_transaction",
      requested_by: requested_by,
      manager_username: manager.username,
      manager_pin: "4321",
      store: transaction.store,
      pos_transaction: transaction
    )
  end
end
