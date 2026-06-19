# frozen_string_literal: true

module PosHelper
  POS_MODES = %w[sale return exchange].freeze

  def pos_mode_label(mode)
    mode.to_s.humanize
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
end
