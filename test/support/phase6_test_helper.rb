# frozen_string_literal: true

module Phase6TestHelper
  def grant_all_phase6_permissions!(user, store: nil)
    Seeds::Phase6Permissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def grant_phase6_tender_permissions!(user, store: nil)
    %w[
      pos.tenders.cash
      pos.tenders.card
      pos.tenders.check
      pos.tenders.store_credit
      pos.tenders.gift_card
      pos.tenders.refund
      pos.refunds.store_credit
    ].each do |permission_key|
      grant_permission!(user, permission_key, store: store)
    end
  end

  def complete_pos_transaction!(transaction:, completed_by_user:, register_session:, confirmed_inactive: true, pos_authorization_id: nil)
    grant_phase6_tender_permissions!(completed_by_user, store: transaction.store)

    Pos::CompleteTransaction.call!(
      transaction: transaction.reload,
      completed_by_user: completed_by_user,
      register_session: register_session,
      confirmed_inactive: confirmed_inactive,
      pos_authorization_id: pos_authorization_id
    )
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
      transaction.pos_tenders.create!(default_tender_attrs(transaction, tender_attrs))
    end

    transaction
  end

  def complete_pos_sale!(transaction:, user:, register_session:, tenders: nil)
    if tenders
      transaction.pos_tenders.destroy_all
      tenders.each { |attrs| transaction.pos_tenders.create!(default_tender_attrs(transaction, attrs)) }
    end

    Pos::RecalculateTransaction.call!(transaction, business_date: register_session.business_date)
    unless transaction.pos_tenders.exists?
      transaction.pos_tenders.create!(
        default_tender_attrs(transaction, tender_type: "cash", amount_cents: transaction.total_cents)
      )
    end

    complete_pos_transaction!(
      transaction: transaction,
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

  def grant_force_close_authorization!(register_session:, requested_by:, manager: nil)
    manager ||= create_user!(username: "force-close-manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: register_session.store)

    Pos::AuthorizationRequest.grant!(
      authorization_type: "force_close_register",
      requested_by: requested_by,
      manager_username: manager.username,
      manager_pin: "4321",
      store: register_session.store,
      pos_register_session: register_session
    )
  end

  def setup_pos_workstation!(user:, store: nil, workstation: nil, opening_cash_cents: 0, login: true, grant_permissions: true, inventory_qty: 5, **variant_attrs)
    store ||= create_store!
    workstation ||= create_workstation!(store: store)
    grant_all_phase6_permissions!(user, store: store) if grant_permissions

    default_variant_attrs = {
      sku: "POS-TEST-#{SecureRandom.hex(3)}",
      selling_price_cents: 1500
    }
    variant = create_product_variant!(**default_variant_attrs.merge(variant_attrs))
    create_store_tax_category_rate!(store: store, tax_category: variant.sub_department.default_tax_category)
    if inventory_qty.positive?
      receive_inventory!(store: store, vendor: create_vendor!, variant: variant, user: user, quantity: inventory_qty)
    end
    login_user!(user, workstation: workstation) if login

    register_session = open_register_session!(
      store: store,
      workstation: workstation,
      user: user,
      opening_cash_cents: opening_cash_cents
    )

    {
      store: store,
      workstation: workstation,
      variant: variant,
      register_session: register_session
    }
  end

  def create_completed_pos_sale!(user:, register_session:, variant:, store:, workstation:, quantity: 1, unit_price_cents: nil, **attrs)
    unit_price_cents ||= variant.selling_price_cents
    extended = unit_price_cents * quantity
    transaction = create_pos_transaction!(
      store: store,
      workstation: workstation,
      user: user,
      lines: [ {
        product_variant: variant,
        quantity: quantity,
        unit_price_cents: unit_price_cents,
        extended_price_cents: extended
      } ],
      **attrs
    )
    complete_pos_sale!(transaction: transaction, user: user, register_session: register_session)
    transaction.reload
  end

  def create_pos_tender!(transaction, attrs = {})
    transaction.pos_tenders.create!(default_tender_attrs(transaction, attrs))
  end

  def grant_no_receipt_return_authorization!(transaction, requested_by: nil, manager: nil)
    requested_by ||= transaction.cashier_user
    manager ||= create_user!(username: "no-receipt-manager-#{SecureRandom.hex(4)}", pin: "4321")
    grant_permission!(manager, "pos.authorizations.grant", store: transaction.store)

    Pos::AuthorizationRequest.grant!(
      authorization_type: "no_receipt_return",
      requested_by: requested_by,
      manager_username: manager.username,
      manager_pin: "4321",
      store: transaction.store,
      pos_transaction: transaction
    )
  end

  def default_tender_attrs(transaction, attrs)
    attrs = attrs.symbolize_keys
    line_number = attrs[:line_number] || PosTender.next_line_number_for(transaction)
    card_brand = if attrs[:tender_type] == "card"
      attrs[:card_brand] || "other"
    else
      attrs[:card_brand]
    end

    attrs.merge(line_number: line_number, card_brand: card_brand).compact
  end
end
