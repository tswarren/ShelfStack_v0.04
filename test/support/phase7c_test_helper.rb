# frozen_string_literal: true

module Phase7cTestHelper
  def seed_phase7c_reference_data!
    Seeds::Phase7cPermissions.seed!
    Seeds::Phase7cBuyback.seed!
    Seeds::Phase7bStoredValue.seed!
    seed_phase3_reference_data!
  end

  def grant_all_phase7c_permissions!(user, store: nil)
    Seeds::Phase7cPermissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def buyback_sub_department!
    sub = SubDepartment.find_by(sub_department_key: "general_trade")
    sub.update!(buyback_allowed: true) if sub && !sub.buyback_allowed?
    sub || begin
      dept = Department.find_by(department_number: "010") || create_department!(
        department_number: "010", name: "Books", short_name: "Books"
      )
      SubDepartment.create!(
        sub_department_key: "buyback_test",
        name: "Buyback Test",
        short_name: "Buyback",
        department: dept,
        default_tax_category: create_tax_category!,
        default_pricing_model: "trade_discount",
        buyback_allowed: true,
        active: true
      )
    end
  end

  def buyback_used_condition!
    condition = ProductCondition.find_by(condition_key: "used_good")
    if condition
      condition.update!(buyback_eligible: true) unless condition.buyback_eligible?
      return condition
    end

    create_product_condition!(
      condition_key: "used_good",
      short_name: "Good",
      new_condition: false,
      sku_component: "UG",
      buyback_eligible: true
    )
  end

  def create_buyback_customer!(**attrs)
    Customer.create!({
      display_name: "Buyback Seller",
      first_name: "Pat",
      last_name: "Seller",
      address_line1: "1 Main St",
      city: "Town",
      region_code: "MI",
      postal_code: "48302",
      country_code: "US",
      active: true
    }.merge(attrs))
  end

  def create_buyback_session!(store:, customer:, actor:, **attrs)
    Buybacks::StartSession.call!(store: store, customer: customer, actor: actor, **attrs)
  end

  def accept_buyback_line!(line:, session:, actor:, variant:, condition:, sub_department:, payout_mode: "cash",
                           save_proposal: true, record_decision: true, **attrs)
    session.update!(payout_mode: payout_mode) if session.payout_mode.blank? || payout_mode != "cash"
    session.update!(workstation: create_workstation!(store: session.store)) if session.workstation.blank?

    offer = payout_mode == "no_value_donation" ? 0 : (attrs[:offer_cents] || 500)
    resale = attrs[:resale_price_cents] || 2000
    trade_offer = attrs[:trade_offer_cents] || (offer + 100)

    line.update!(
      product: variant.product,
      catalog_item: variant.product.catalog_item,
      list_price_cents: variant.product.list_price_cents
    )

    Buybacks::UpdateProposalLine.call!(
      line: line,
      session: session,
      actor: actor,
      product_condition: condition,
      sub_department: sub_department,
      proposed_resale_price_cents: resale,
      proposed_cash_offer_cents: offer,
      proposed_trade_credit_offer_cents: trade_offer,
      resale_override_reason: attrs[:resale_override_reason] || "Test setup",
      cash_override_reason: attrs[:cash_override_reason] || "Test setup",
      trade_credit_override_reason: attrs[:trade_credit_override_reason] || "Test setup"
    )

    if save_proposal
      Buybacks::SaveProposal.call!(session: session, actor: actor) if session.reload.buyback_number.blank?
      if session.buyback_number.present? && (session.quoted? || session.decision?)
        line.reload.update!(status: "offered")
      end
      Buybacks::OpenCustomerDecision.call!(session: session.reload, actor: actor) unless session.decision?
    end

    return line unless record_decision

    outcome = case payout_mode
    when "no_value_donation" then "donated_by_customer"
    else "accepted_by_customer"
    end

    Buybacks::RecordCustomerDecision.call!(
      line: line.reload,
      session: session.reload,
      actor: actor,
      outcome: attrs[:outcome] || outcome
    )
  end

  def grant_void_buyback_authorization!(register_session:, requested_by:, manager: nil)
    manager ||= requested_by
    grant_permission!(manager, "pos.authorizations.grant", store: register_session.store)
    Pos::AuthorizationRequest.grant!(
      authorization_type: "void_buyback",
      requested_by: requested_by,
      manager_username: manager.username,
      manager_pin: "1234",
      store: register_session.store,
      pos_register_session: register_session
    )
  end
end
