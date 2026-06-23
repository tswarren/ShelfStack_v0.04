# frozen_string_literal: true

module Phase7bTestHelper
  def seed_phase7b_reference_data!
    Seeds::Phase7bPermissions.seed!
    Seeds::Phase7bStoredValue.seed!
  end

  def grant_all_phase7b_permissions!(user, store: nil)
    Seeds::Phase7bPermissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def grant_pos_stored_value_tender_permissions!(user, store:)
    %w[pos.tenders.store_credit pos.tenders.gift_card pos.refunds.store_credit pos.gift_cards.issue].each do |key|
      next if Authorization.allowed?(user: user, permission_key: key, store: store)

      grant_permission!(user, key, store: store)
    end
  end

  def ensure_gift_card_sale_classification!(store:)
    tax_category = TaxCategory.find_or_create_by!(name: "Gift Card") do |record|
      record.short_name = "Gift Card"
      record.sort_order = 95
      record.active = true
    end

    department = Department.find_by(department_number: "010") || create_department!(
      department_number: "010",
      name: "Tracking",
      short_name: "Tracking"
    )

    sub_department = SubDepartment.find_or_create_by!(sub_department_key: "gift_cards") do |record|
      record.name = "Gift Cards / Certificates"
      record.short_name = "Gift Cards"
      record.department = department
      record.default_tax_category = tax_category
      record.default_pricing_model = "pass_through"
      record.active = true
    end

    unless StoreTaxCategoryRate.active_records.exists?(store: store, tax_category: tax_category)
      non_taxable = StoreTaxRate.find_by(store: store, short_name: "Non-Taxable") ||
        create_store_tax_rate!(
          store: store,
          name: "Non-Taxable",
          short_name: "Non-Taxable",
          tax_identifier: "N",
          tax_rate_bps: 0
        )
      create_store_tax_category_rate!(
        store: store,
        tax_category: tax_category,
        store_tax_rate: non_taxable,
        effective_on: Date.new(2020, 1, 1)
      )
    end

    sub_department
  end

  def add_gift_card_sale_line!(transaction:, actor:, amount_cents:)
    Pos::AddGiftCardSaleLine.call!(
      transaction: transaction,
      actor: actor,
      amount_cents: amount_cents,
      line_number: transaction.pos_transaction_lines.maximum(:line_number).to_i + 1
    )
  end

  def issue_stored_value_credit!(account:, store:, actor:, amount_cents:)
    StoredValue::Issue.call(
      account: account,
      store: store,
      actor: actor,
      amount_cents: amount_cents,
      reason_code: stored_value_reason_code!("manual_issue")
    )
  end

  def create_stored_value_account!(attrs = {})
    attrs = attrs.dup
    store = attrs.delete(:issuing_store)
    store ||= create_store!(store_number: format("%03d", Store.count + 1))
    StoredValueAccount.create!(
      {
        issuing_store: store,
        account_type: "merchandise_credit",
        current_balance_cents: 0,
        active: true
      }.merge(attrs)
    )
  end

  def stored_value_reason_code!(key = "manual_issue")
    StoredValueReasonCode.find_by!(reason_key: key)
  end

  def generate_test_identifier!(account:, actor:)
    StoredValue::CreateIdentifier.call(
      account: account,
      actor: actor,
      identifier_type: "generated"
    )
  end
end
