# frozen_string_literal: true

module PosHelper
  POS_MODES = %w[sale return exchange].freeze
  POS_WORKSPACE_MODES = %w[sale return pickup].freeze
  ENTRY_ACTIONS = %w[sale return_receipt return_no_receipt open_ring].freeze

  VOID_REASON_CODES = [
    [ "Cashier error", "cashier_error" ],
    [ "Customer changed mind", "customer_changed_mind" ],
    [ "Duplicate transaction", "duplicate" ],
    [ "Other", "other" ]
  ].freeze

  def pos_mode_label(mode)
    mode.to_s == "pickup" ? "Pickup" : mode.to_s.humanize
  end

  def pos_pickup_mode?
    pos_workspace_mode == "pickup"
  end

  def pos_workspace_mode
    mode = params[:mode].presence || "sale"
    POS_WORKSPACE_MODES.include?(mode) ? mode : "sale"
  end

  def pos_mode_switch_active?(mode)
    carry_forward = params[:carry_forward].presence
    case mode.to_s
    when "sale"
      carry_forward.blank? && !legacy_return_or_pickup_mode?
    when "return"
      carry_forward == "return" || (carry_forward.blank? && params[:mode] == "return")
    when "pickup"
      carry_forward == "pickup" || (carry_forward.blank? && params[:mode] == "pickup")
    else
      false
    end
  end

  def legacy_return_or_pickup_mode?
    params[:mode].in?(%w[return pickup])
  end

  def pos_initial_entry_action(mode)
    mode.to_s == "return" ? "return_receipt" : "sale"
  end

  def pos_derived_transaction_type(transaction)
    transaction.transaction_type.presence || Pos::DeriveTransactionType.call(transaction)
  end

  def pos_draft_type_label(transaction)
    type = pos_derived_transaction_type(transaction)
    return "Draft transaction" if type.blank?

    case type
    when "exchange" then "Exchange"
    else "Draft #{type}"
    end
  end

  def pos_complete_button_label(transaction, confirm_inactive: false, change_cents: nil, remaining_cents: nil)
    type = pos_derived_transaction_type(transaction)
    base = case type
    when "return" then confirm_inactive ? "Complete (confirm inactive) return" : "Refund customer"
    when "exchange" then confirm_inactive ? "Complete (confirm inactive) exchange" : "Complete exchange"
    else confirm_inactive ? "Complete (confirm inactive) sale" : "Complete sale"
    end

    if change_cents.to_i.positive?
      "#{base} — #{pos_money(change_cents)} change due"
    elsif remaining_cents.to_i.positive?
      "#{base} — #{pos_money(remaining_cents)} still due"
    else
      base
    end
  end

  ExchangeSummary = Data.define(:return_total_cents, :sale_total_cents, :amount_due_cents)

  def pos_exchange_summary(transaction)
    return nil unless pos_derived_transaction_type(transaction) == "exchange"

    sale_total = 0
    return_total = 0
    transaction.pos_transaction_lines.each do |line|
      next if line.quantity.zero?

      line_total = pos_line_total_cents(line)
      if line.quantity.positive?
        sale_total += line_total
      else
        return_total += line_total
      end
    end

    ExchangeSummary.new(
      return_total_cents: return_total,
      sale_total_cents: sale_total,
      amount_due_cents: transaction.total_cents
    )
  end

  def pos_line_total_cents(line)
    amount = line.extended_price_cents.to_i + line.tax_cents.to_i
    line.quantity.negative? ? -amount.abs : amount
  end

  def pos_line_display_title(line)
    if line.gift_card_sale_line?
      amount = pos_money(line.unit_price_cents)
      return "#{PosTransactionLine::GIFT_CARD_SALE_DESCRIPTION} #{amount}"
    end

    if line.open_ring_line?
      return line.open_ring_description.presence || "Open ring item"
    end

    line.variant_name_snapshot.presence ||
      line.product_variant&.name ||
      "Item"
  end

  def pos_open_ring_line_sku(line)
    line.sub_department_name_snapshot.presence ||
      line.sub_department&.name ||
      "Open ring"
  end

  def pos_receipt_line_sku(line)
    return "Gift card" if line.gift_card_sale_line?
    return pos_open_ring_line_sku(line) if line.open_ring_line?

    line.variant_sku_snapshot.presence ||
      line.product_variant&.sku ||
      "Item"
  end

  def pos_line_display_sku(line)
    return "Gift card" if line.gift_card_sale_line?

    return pos_open_ring_line_sku(line) if line.open_ring_line?

    line.variant_sku_snapshot.presence ||
      line.product_variant&.sku ||
      "Item"
  end

  def pos_line_return_source_label(line)
    return unless line.return_line? && line.source_transaction.present?

    "From receipt #{line.source_transaction.transaction_number}"
  end

  PickupSummary = Data.define(:customer_name, :request_numbers, :line_count)
  PickupLineContext = Data.define(:customer_name, :request_number, :label)

  def pos_transaction_pickup_summary(transaction)
    pickup_lines = transaction.pos_transaction_lines.select { |line| line.inventory_reservation_id.present? }
    return nil if pickup_lines.empty?

    customer_names = pickup_lines.filter_map do |line|
      line.inventory_reservation&.customer&.display_name ||
        line.customer_request_line&.customer_request&.customer&.display_name
    end.uniq

    request_numbers = pickup_lines.filter_map do |line|
      line.customer_request_line&.customer_request&.request_number
    end.uniq

    PickupSummary.new(
      customer_name: customer_names.one? ? customer_names.first : customer_names.join(", "),
      request_numbers: request_numbers,
      line_count: pickup_lines.size
    )
  end

  def pos_line_pickup_context(line)
    return nil unless line.inventory_reservation_id.present?

    customer_name = line.inventory_reservation&.customer&.display_name ||
      line.customer_request_line&.customer_request&.customer&.display_name
    request_number = line.customer_request_line&.customer_request&.request_number

    PickupLineContext.new(
      customer_name: customer_name,
      request_number: request_number,
      label: [ customer_name, request_number ].compact.join(" · ")
    )
  end

  def pos_line_pickup_label(line)
    context = pos_line_pickup_context(line)
    return if context.blank?

    [ "Customer pickup", context.label ].compact.join(" · ")
  end

  def pos_line_price_editable?(line)
    !(line.return_line? && line.source_transaction_line_id.present?)
  end

  def pos_cart_line_edit_panel_available?(line)
    !line.gift_card_sale_line?
  end

  def pos_cart_line_discount_panel_available?(line)
    !line.return_line? && !line.gift_card_sale_line?
  end

  def pos_cart_line_tax_panel_available?(line)
    pos_line_tax_override_eligible?(line)
  end

  def pos_cart_line_panel_open?(line, panel_error)
    panel_error.present? && panel_error[:line_id].to_i == line.id
  end

  def pos_cart_line_active_panel(line, panel_error)
    return panel_error[:panel].to_s if pos_cart_line_panel_open?(line, panel_error)

    nil
  end

  def pos_tender_field_label(tender_type, transaction)
    if transaction.total_cents.negative?
      case tender_type
      when "cash" then "Refund amount"
      when "card" then "Card refund"
      else "#{tender_type.humanize} refund"
      end
    elsif tender_type == "cash" && transaction.total_cents.positive?
      "Cash"
    else
      tender_type.humanize
    end
  end

  def pos_readiness_panel_class(readiness)
    if readiness.complete_ready?
      "ss-pos-readiness--ready"
    elsif readiness.structural_blocked?
      "ss-pos-readiness--blocked"
    else
      "ss-pos-readiness--pending"
    end
  end

  def pos_readiness_panel_title(readiness)
    if readiness.complete_ready?
      "Ready to complete"
    elsif readiness.structural_blocked?
      "Cannot complete yet"
    else
      "Enter tender to complete"
    end
  end

  def pos_supervisor_auth_message(check)
    case check.key
    when :discount_auth then "This discount exceeds the cashier limit. A manager must enter their username and PIN to approve."
    when :discount_reason_auth then "This discount reason requires manager approval before it can be applied."
    when :no_receipt_return then "This return has no receipt. A manager must enter their username and PIN to approve."
    when :cash_refund_auth then "This cash refund exceeds the limit. A manager must enter their username and PIN to approve."
    when :reserved_stock_auth then "This sale uses stock reserved for customer pickup. A manager must approve selling without a reservation line."
    else "A manager must enter their username and PIN to approve this action."
    end
  end

  def pos_supervisor_authorization_type(check)
    pos_supervisor_authorization_type_for_key(check.key)
  end

  def pos_supervisor_authorization_type_for_key(key)
    case key
    when :discount_auth then "discount_over_limit"
    when :discount_reason_auth then "discount_reason_approval"
    when :no_receipt_return then "no_receipt_return"
    when :cash_refund_auth then "cash_refund_over_threshold"
    when :reserved_stock_auth then "sell_reserved_stock_override"
    end
  end

  def pos_lookup_preview_text(variant)
    price = pos_money(variant[:selling_price_cents] || variant["selling_price_cents"])
    on_hand = variant[:quantity_on_hand] || variant["quantity_on_hand"] || 0
    available = variant[:quantity_available] || variant["quantity_available"] || on_hand
    reserved = variant[:quantity_reserved] || variant["quantity_reserved"] || 0
    sku = variant[:sku] || variant["sku"]
    name = variant[:name] || variant["name"]
    "#{sku} — #{name}\nOn hand: #{on_hand} · Available: #{available} · Reserved: #{reserved} · #{price}"
  end

  def pos_void_reason_options
    VOID_REASON_CODES
  end

  def pos_money(cents)
    return "—" if cents.nil?

    format("$%.2f", cents / 100.0)
  end

  def pos_money_field(name, cents_value = nil, **options)
    dollar_value = cents_value.nil? ? nil : format("%.2f", cents_value / 100.0)
    number_field_tag(name, dollar_value, { step: 0.01, min: options.delete(:min) }.merge(options))
  end

  def pos_discount_type_options
    [ [ "Amount ($)", "amount" ], [ "Percent (%)", "percent" ] ]
  end

  def pos_discount_reason_options
    DiscountReason.active_records.order(:sort_order, :name).map do |reason|
      [
        reason.name,
        reason.id,
        {
          data: {
            requires_authorization: reason.requires_authorization?,
            requires_note: reason.requires_note?
          }
        }
      ]
    end
  end

  def pos_discount_reason_requires_authorization?(reason_id)
    return false if reason_id.blank?

    DiscountReason.active_records.find_by(id: reason_id)&.requires_authorization?
  end

  def pos_tax_exception_reason_options
    TaxExceptionReason.active_records.for_exemption.order(:sort_order, :name)
  end

  def pos_tax_override_reason_options
    pos_tax_exception_reason_select_options(TaxExceptionReason.active_records.for_rate_override)
  end

  def pos_tax_exception_reason_select_options(scope)
    scope.order(:sort_order, :name).map do |reason|
      [
        reason.name,
        reason.id,
        {
          data: {
            requires_note: reason.requires_note?,
            requires_certificate: reason.requires_certificate?
          }
        }
      ]
    end
  end

  def pos_tax_category_options
    TaxCategory.active_records.order(:name)
  end

  def pos_line_tax_override_eligible?(line)
    return false if line.return_line? && line.source_transaction_line_id.present?
    return false if line.gift_card_sale_line?
    return false if line.open_ring_line? && line.tax_category_id.blank?
    return false unless line.quantity.positive?

    true
  end

  def pos_transaction_tax_exemption_summary(transaction)
    expected_tax_cents = transaction.normal_tax_cents.to_i
    applied_tax_cents = transaction.tax_cents.to_i
    {
      expected_tax_cents: expected_tax_cents,
      tax_removed_cents: [ expected_tax_cents - applied_tax_cents, 0 ].max
    }
  end

  def pos_receipt_tax_exemption(transaction)
    exemption = transaction.pos_tax_exemptions.active_records.first
    return if exemption.blank?

    {
      reason_name: exemption.tax_exception_reason.name,
      certificate_number: exemption.certificate_number
    }
  end

  def pos_transaction_item_discount_cents(transaction)
    transaction.pos_transaction_lines.sum(&:line_discount_cents)
  end

  def pos_transaction_discount_base_cents(transaction)
    transaction.pos_transaction_lines.sum do |line|
      next 0 unless line.quantity.positive?

      eligibility = Pos::DiscountEligibilityResolver.call(line)
      next 0 unless eligibility.discountable

      [ Pos::DiscountInput.line_base_cents(line) - line.line_discount_cents.to_i - line.transaction_discount_cents.to_i, 0 ].max
    end
  end

  def pos_transaction_applied_transaction_discount_cents(transaction)
    transaction.pos_discount_applications.active_records.where(scope: "transaction").sum(:applied_discount_cents)
  end

  def pos_transaction_discount_modal_available?(transaction, user: current_user, store: current_store)
    transaction.present? &&
      transaction.editable? &&
      Authorization.allowed?(user: user, permission_key: "pos.discounts.transaction.apply", store: store)
  end

  def pos_discount_amount_display(cents)
    format("%.2f", cents.to_i / 100.0)
  end

  def pos_return_disposition_options
    PosTransactionLine::RETURN_DISPOSITIONS.map { |value| [ value.humanize, value ] }
  end

  def pos_tendered_display_cents(tender)
    return nil if tender.blank?

    Pos::TenderSync.tendered_cents_for(tender)
  end

  def pos_tender_type_options
    PosTender::PHASE6_ALLOWED_TYPES.map { |value| [ value.humanize, value ] }
  end

  def pos_can_use_stored_value_tender?(transaction, tender_type, user = current_user)
    Pos::TenderTypePolicy.allowed?(transaction, actor: user, tender_type:, store: transaction.store)
  end

  def pos_can_issue_gift_card_sale?(transaction, user = current_user)
    Pos::GiftCardSalePolicy.issue_permitted?(actor: user, store: transaction.store)
  end

  def pos_gift_card_sale_activation_status(line)
    if line.stored_value_identifier&.display_value_masked.present?
      if line.reload_gift_card_sale?
        "Reloading card #{line.stored_value_identifier.display_value_masked}"
      else
        "Card #{line.stored_value_identifier.display_value_masked}"
      end
    elsif line.generate_stored_value_identifier?
      "A card number will be auto-generated at completion."
    else
      "Leave blank to auto-generate, or enter an existing or new card number."
    end
  end

  def pos_customer_stored_value_account(transaction, tender_type: "store_credit")
    return if transaction.customer_id.blank?

    account_type = Pos::StoredValueTenderSupport.default_account_type_for_tender(tender_type)
    StoredValueAccount.active_records.find_by(
      customer_id: transaction.customer_id,
      issuing_store_id: transaction.store_id,
      account_type: account_type
    )
  end

  def pos_stored_value_tender_label(tender)
    base = tender.tender_type == "gift_card" ? "Gift card" : "Store credit"
    if tender.stored_value_identifier&.display_value_masked.present?
      "#{base} #{tender.stored_value_identifier.display_value_masked}"
    elsif tender.stored_value_account&.customer&.display_name.present?
      "#{base} – #{tender.stored_value_account.customer.display_name}"
    elsif tender.stored_value_account&.holder_name_snapshot.present?
      "#{base} – #{tender.stored_value_account.holder_name_snapshot}"
    else
      base
    end
  end

  def pos_stored_value_receipt_balance_cents(tender)
    return unless tender.stored_value_account_id.present?

    entry = StoredValueLedgerEntry.where(source: tender).order(posted_at: :desc, id: :desc).first
    entry&.balance_after_cents || tender.stored_value_account&.current_balance_cents
  end

  def pos_stored_value_receipt_identifier_value(tender)
    identifier = tender.stored_value_identifier
    return if identifier.blank? || identifier.encrypted_value.blank?

    StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
    )
  end

  def pos_gift_card_sale_receipt_ledger_entry(line)
    return unless line.gift_card_sale_line?

    StoredValueLedgerEntry.where(source: line, entry_type: "issue").order(posted_at: :desc, id: :desc).first
  end

  def pos_gift_card_sale_receipt_balance_cents(line)
    entry = pos_gift_card_sale_receipt_ledger_entry(line)
    entry&.balance_after_cents || line.stored_value_account&.current_balance_cents
  end

  def pos_gift_card_sale_receipt_identifier_value(line)
    identifier = line.stored_value_identifier
    return if identifier.blank? || identifier.encrypted_value.blank?

    StoredValue::IdentifierCodec.format_display(
      StoredValue::IdentifierVault.decrypt(identifier.encrypted_value)
    )
  end

  def pos_gift_card_sale_receipt_reload?(line)
    entry = pos_gift_card_sale_receipt_ledger_entry(line)
    return false if entry.blank?

    entry.balance_after_cents.to_i > entry.amount_delta_cents.to_i
  end

  def pos_stored_value_receipt_balance_label(tender)
    tender.issue_tender? ? "New balance" : "Remaining balance"
  end

  def pos_card_brand_options
    PosTender::CARD_BRANDS.map { |brand| [ brand.humanize, brand ] }
  end

  def pos_settlement_row_type_label(tender_type, transaction)
    pos_tender_field_label(tender_type, transaction)
  end

  def pos_settlement_row_summary(row, transaction)
    parts = pos_settlement_row_summary_parts(row, transaction)
    "#{parts[:label]} — #{parts[:amount]}"
  end

  def pos_settlement_row_summary_parts(row, transaction)
    refund = transaction.total_cents.to_i.negative?

    case row.tender_type
    when "cash"
      cents = refund ? row.amount_cents.to_i.abs : pos_tendered_display_cents(row).to_i
      label = refund ? "Cash refund" : "Cash"
      { label: label, amount: pos_money(cents) }
    when "card"
      brand = row.card_brand.to_s.humanize
      label = if row.card_last_four.present?
        "Card – #{brand} #{row.card_last_four}"
      else
        "Card – #{brand}"
      end
      amount_cents = refund && row.amount_cents.to_i.negative? ? row.amount_cents.abs : row.amount_cents.to_i
      { label: label, amount: pos_money(amount_cents) }
    when "check"
      label = row.check_number.present? ? "Check ##{row.check_number}" : "Check"
      amount_cents = refund && row.amount_cents.to_i.negative? ? row.amount_cents.abs : row.amount_cents.to_i
      { label: label, amount: pos_money(amount_cents) }
    when "store_credit", "gift_card"
      label = pos_stored_value_tender_label(row)
      amount_cents = refund && row.amount_cents.to_i.negative? ? row.amount_cents.abs : row.amount_cents.to_i
      { label: label, amount: pos_money(amount_cents) }
    else
      { label: row.tender_type.humanize, amount: pos_money(0) }
    end
  end

  def pos_line_gross_cents(line)
    line.unit_price_cents * line.quantity.abs
  end

  def pos_line_transaction_discount_cents(line)
    return line.transaction_discount_cents if line.transaction_discount_cents.to_i.positive?

    base = [ pos_line_gross_cents(line) - line.line_discount_cents.to_i, 0 ].max
    [ base - line.extended_price_cents, 0 ].max
  end

  def pos_line_total_discount_cents(line)
    [ pos_line_gross_cents(line) - line.extended_price_cents, 0 ].max
  end

  def pos_line_discount_breakdown(line)
    parts = pos_line_discount_breakdown_parts(line)
    return parts.join(", ") if parts.any?

    legacy_parts = []
    legacy_parts << "line #{pos_money(line.line_discount_cents)}" if line.line_discount_cents.to_i.positive?
    txn_share = pos_line_transaction_discount_cents(line)
    legacy_parts << "order #{pos_money(txn_share)}" if txn_share.positive?
    legacy_parts.join(", ")
  end

  def pos_line_discount_breakdown_parts(line)
    parts = []
    line.pos_discount_applications.active_records.order(:stack_order).each do |application|
      parts << "#{application.discount_reason.name} #{pos_money(application.applied_discount_cents)}"
    end

    transaction_allocations_for_line(line).each do |allocation|
      reason_name = allocation.pos_discount_application.discount_reason.name
      parts << "order #{reason_name} #{pos_money(allocation.allocated_discount_cents)}"
    end

    parts
  end

  def transaction_allocations_for_line(line)
    line.pos_discount_allocations
      .joins(:pos_discount_application)
      .merge(PosDiscountApplication.active_records.where(scope: "transaction"))
      .includes(pos_discount_application: :discount_reason)
      .order("pos_discount_applications.stack_order")
  end

  def pos_line_tax_indicator(line)
    identifier = pos_line_tax_identifier(line)
    return "—" if identifier.blank?

    identifier
  end

  TaxSubtotal = Data.define(:short_name, :tax_cents)

  def pos_transaction_tax_subtotals(transaction)
    grouped = transaction.pos_transaction_lines.group_by { |line| pos_line_tax_short_name(line) }

    grouped.filter_map do |short_name, lines|
      tax_cents = lines.sum { |line| line.quantity.negative? ? -line.tax_cents : line.tax_cents }
      next if tax_cents.zero? && lines.all? { |line| line.tax_cents.zero? }

      TaxSubtotal.new(short_name: short_name, tax_cents: tax_cents)
    end.sort_by(&:short_name)
  end

  def pos_line_tax_identifier(line)
    line.tax_identifier_snapshot.presence || resolve_store_tax_rate_for_line(line)&.tax_identifier
  end

  def pos_line_tax_short_name(line)
    line.store_tax_rate_short_name_snapshot.presence || resolve_store_tax_rate_for_line(line)&.short_name || "Tax"
  end

  def resolve_store_tax_rate_for_line(line)
    return line.store_tax_rate if line.store_tax_rate.present?
    return if line.tax_category.blank?

    transaction = line.pos_transaction
    TaxRateLookup.call(
      store: transaction.store,
      tax_category: line.tax_category,
      date: transaction.business_date || Date.current
    )
  rescue TaxRateLookup::Error
    nil
  end

  def pos_receipt_change_cents(transaction)
    pos_settlement_tenders(transaction).sum(&:change_display_cents)
  end

  def pos_settlement_tenders(transaction)
    if transaction.persisted?
      transaction.pos_tenders.settlement_rows
    else
      transaction.pos_tenders.reject(&:reverses_tender_id)
    end
  end

  def pos_tender_receipt_label(tender)
    case tender.tender_type
    when "card"
      brand = tender.card_brand.to_s.humanize
      if tender.card_last_four.present?
        "#{brand} ending #{tender.card_last_four}"
      else
        brand
      end
    when "check"
      if tender.check_number.present?
        "Check ##{tender.check_number}"
      else
        "Check"
      end
    when "cash"
      tendered = tender.tendered_display_cents
      if tendered > tender.amount_cents
        "Cash tendered"
      else
        "Cash"
      end
    when "store_credit"
      refund = tender.amount_cents.negative?
      refund ? "Store credit issued" : "Store credit redeemed"
    when "gift_card"
      refund = tender.amount_cents.negative?
      refund ? "Gift card credit issued" : "Gift card redeemed"
    else
      tender.tender_type.humanize
    end
  end

  def pos_tender_receipt_amount_cents(tender)
    tendered = tender.tendered_display_cents
    if tender.tender_type == "cash" && tendered > tender.amount_cents
      tendered
    else
      tender.amount_cents
    end
  end

  def pos_receipt_money(cents)
    content_tag(:span, pos_money(cents), class: "ss-receipt-money")
  end

  def pos_receipt_store_address(store)
    parts = [ store.city, store.region_code, store.postal_code ].compact_blank
    parts.join(", ")
  end

  ReceiptTaxSubtotal = Data.define(:label, :tax_cents)

  def pos_receipt_tax_subtotals(transaction)
    grouped = transaction.pos_transaction_lines.group_by do |line|
      identifier = pos_line_tax_identifier(line).presence || "—"
      short_name = pos_line_tax_short_name(line)
      "#{identifier} - #{short_name}"
    end

    grouped.filter_map do |label, lines|
      tax_cents = lines.sum { |line| line.quantity.negative? ? -line.tax_cents : line.tax_cents }
      next if tax_cents.zero? && lines.all? { |line| line.tax_cents.zero? }

      ReceiptTaxSubtotal.new(label: label, tax_cents: tax_cents)
    end.sort_by(&:label)
  end

  def pos_receipt_item_discounts_total(transaction)
    transaction.pos_transaction_lines.sum do |line|
      amount = line.line_discount_cents.to_i
      line.quantity.negative? ? -amount : amount
    end
  end

  def pos_receipt_savings_total(transaction)
    item_total = pos_receipt_item_discounts_total(transaction).abs
    order_total = transaction.discount_cents.to_i
    item_total + order_total
  end

  def pos_receipt_signed_cents(cents, negative: false)
    negative ? -cents.abs : cents
  end

  def pos_receipt_line_gross_cents(line)
    amount = pos_line_gross_cents(line)
    line.return_line? ? -amount : amount
  end

  def pos_receipt_line_net_cents(line)
    amount = line.extended_price_cents.to_i
    line.return_line? ? -amount.abs : amount
  end

  def pos_receipt_line_header_amount_cents(line)
    pos_receipt_line_net_cents(line)
  end

  def pos_receipt_line_list_amount_cents(line)
    pos_receipt_line_gross_cents(line)
  end

  def pos_receipt_line_unit_list_amount_cents(line)
    line.unit_price_cents.to_i
  end

  def pos_receipt_line_unit_paid_amount_cents(line)
    qty = line.quantity.abs
    return line.unit_price_cents.to_i if qty <= 1

    (line.extended_price_cents.to_f / qty).round
  end

  def pos_receipt_line_per_unit_discount_cents(line, total_discount_cents)
    qty = line.quantity.abs
    return total_discount_cents.to_i if qty <= 1

    (total_discount_cents.to_f / qty).round
  end

  ReceiptLineDiscountDetail = Data.define(:label, :amount_cents)

  def pos_receipt_line_discount_details(line)
    return [] if line.return_line? || line.gift_card_sale_line?

    details = pos_receipt_line_discount_details_from_applications(line)
    details = legacy_receipt_line_discount_details(line) if details.empty?

    details.map do |detail|
      ReceiptLineDiscountDetail.new(
        label: detail.label,
        amount_cents: pos_receipt_line_per_unit_discount_cents(line, detail.amount_cents)
      )
    end
  end

  def pos_receipt_line_discount_details_from_applications(line)
    details = []
    line.pos_discount_applications.active_records.order(:stack_order).each do |application|
      details << ReceiptLineDiscountDetail.new(
        label: application.discount_reason.name,
        amount_cents: application.applied_discount_cents.to_i
      )
    end

    transaction_allocations_for_line(line).each do |allocation|
      reason_name = allocation.pos_discount_application.discount_reason.name
      details << ReceiptLineDiscountDetail.new(
        label: "Order discount — #{reason_name}",
        amount_cents: allocation.allocated_discount_cents.to_i
      )
    end

    details
  end

  def legacy_receipt_line_discount_details(line)
    details = []
    if line.line_discount_cents.to_i.positive?
      details << ReceiptLineDiscountDetail.new(label: "Item discount", amount_cents: line.line_discount_cents.to_i)
    end

    txn_share = pos_line_transaction_discount_cents(line)
    if txn_share.positive?
      details << ReceiptLineDiscountDetail.new(label: "Order discount", amount_cents: txn_share)
    end

    details
  end

  def pos_receipt_line_show_discount_details?(line)
    pos_receipt_line_discount_details(line).any?
  end

  def pos_receipt_line_show_list_detail?(line)
    return false if line.return_line?

    pos_receipt_line_list_amount_cents(line) != pos_receipt_line_header_amount_cents(line)
  end

  def pos_receipt_line_show_quantity_detail?(line)
    return false unless line.merchandise_line?
    return false if line.gift_card_sale_line?

    line.quantity.abs > 1
  end

  def pos_receipt_discounted_subtotal_cents(transaction)
    transaction.pos_transaction_lines.sum do |line|
      pos_receipt_line_net_cents(line)
    end
  end

  def pos_transaction_items_sold_count(transaction)
    transaction.pos_transaction_lines.sum { |line| line.quantity.positive? ? line.quantity : 0 }
  end

  def pos_transaction_items_returned_count(transaction)
    transaction.pos_transaction_lines.sum { |line| line.quantity.negative? ? line.quantity.abs : 0 }
  end
end
