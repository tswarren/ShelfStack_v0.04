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
    when :reserved_stock_auth then "This sale uses stock reserved for customer pickup. A manager must approve selling without a reservation line."
    else "A manager must enter their username and PIN to approve this action."
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

  def pos_receipt_line_item_discount_display_cents(line)
    line.line_discount_cents.to_i.abs
  end

  def pos_receipt_line_show_list_detail?(line)
    return false if line.return_line?

    pos_receipt_line_list_amount_cents(line) != pos_receipt_line_header_amount_cents(line)
  end

  def pos_receipt_line_show_item_discount_detail?(line)
    return false if line.return_line?

    line.line_discount_cents.to_i.positive?
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
