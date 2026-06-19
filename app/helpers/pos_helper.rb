# frozen_string_literal: true

module PosHelper
  POS_MODES = %w[sale return exchange].freeze
  ENTRY_ACTIONS = %w[sale return_receipt return_no_receipt open_ring].freeze

  VOID_REASON_CODES = [
    ["Cashier error", "cashier_error"],
    ["Customer changed mind", "customer_changed_mind"],
    ["Duplicate transaction", "duplicate"],
    ["Other", "other"]
  ].freeze

  def pos_mode_label(mode)
    mode.to_s.humanize
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
    return pos_open_ring_line_sku(line) if line.open_ring_line?

    line.variant_sku_snapshot.presence ||
      line.product_variant&.sku ||
      "Item"
  end

  def pos_line_display_sku(line)
    return pos_open_ring_line_sku(line) if line.open_ring_line?

    line.variant_sku_snapshot.presence ||
      line.product_variant&.sku ||
      "Item"
  end

  def pos_line_return_source_label(line)
    return unless line.return_line? && line.source_transaction.present?

    "From receipt #{line.source_transaction.transaction_number}"
  end

  def pos_line_price_editable?(line)
    !(line.return_line? && line.source_transaction_line_id.present?)
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
    when :no_receipt_return then "This return has no receipt. A manager must enter their username and PIN to approve."
    when :cash_refund_auth then "This cash refund exceeds the limit. A manager must enter their username and PIN to approve."
    else "A manager must enter their username and PIN to approve this action."
    end
  end

  def pos_lookup_preview_text(variant)
    price = pos_money(variant[:selling_price_cents] || variant["selling_price_cents"])
    on_hand = variant[:quantity_on_hand] || variant["quantity_on_hand"] || 0
    sku = variant[:sku] || variant["sku"]
    name = variant[:name] || variant["name"]
    "#{sku} — #{name}\nOn hand: #{on_hand} · #{price}"
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

  def pos_return_disposition_options
    PosTransactionLine::RETURN_DISPOSITIONS.map { |value| [value.humanize, value] }
  end

  def pos_tendered_display_cents(tender)
    return nil if tender.blank?

    Pos::TenderSync.tendered_cents_for(tender)
  end

  def pos_tender_type_options
    PosTender::PHASE6_ALLOWED_TYPES.map { |value| [value.humanize, value] }
  end

  def pos_line_gross_cents(line)
    line.unit_price_cents * line.quantity.abs
  end

  def pos_line_transaction_discount_cents(line)
    return line.transaction_discount_cents if line.transaction_discount_cents.to_i.positive?

    base = [pos_line_gross_cents(line) - line.line_discount_cents.to_i, 0].max
    [base - line.extended_price_cents, 0].max
  end

  def pos_line_total_discount_cents(line)
    [pos_line_gross_cents(line) - line.extended_price_cents, 0].max
  end

  def pos_line_discount_breakdown(line)
    parts = []
    parts << "line #{pos_money(line.line_discount_cents)}" if line.line_discount_cents.to_i.positive?
    txn_share = pos_line_transaction_discount_cents(line)
    parts << "order #{pos_money(txn_share)}" if txn_share.positive?
    parts.join(", ")
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
    cash_tender = transaction.pos_tenders.find { |tender| tender.tender_type == "cash" }
    return 0 if cash_tender.blank?

    tendered = Pos::TenderSync.tendered_cents_for(cash_tender)
    return 0 unless tendered > cash_tender.amount_cents

    tendered - cash_tender.amount_cents
  end

  def pos_tender_receipt_label(tender)
    tendered = Pos::TenderSync.tendered_cents_for(tender)
    if tender.tender_type == "cash" && tendered > tender.amount_cents
      "Cash tendered"
    else
      tender.tender_type.humanize
    end
  end

  def pos_tender_receipt_amount_cents(tender)
    tendered = Pos::TenderSync.tendered_cents_for(tender)
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
    parts = [store.city, store.region_code, store.postal_code].compact_blank
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
end
