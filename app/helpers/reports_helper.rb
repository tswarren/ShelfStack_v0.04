# frozen_string_literal: true

module ReportsHelper
  REPORT_DATE_BASIS_LABELS = {
    "business_date" => "Business date",
    "calendar_date" => "Calendar date",
    "posted_at" => "Posted at",
    "completed_at" => "Completed at",
    "created_at" => "Created at",
    "updated_at" => "Updated at",
    "closed_at" => "Closed at"
  }.freeze

  def format_report_money(cents, signed: false, nil_display: "—")
    return nil_display if cents.nil?

    amount = number_to_currency(cents.abs / 100.0, precision: 2)
    return amount unless signed && cents.negative?

    "- #{amount}"
  end

  def format_report_basis_points(bps)
    format_basis_points(bps)
  end

  def format_report_quantity(quantity, nil_display: "—")
    return nil_display if quantity.nil?

    number_with_delimiter(quantity.to_i)
  end

  def format_report_date(time, basis: nil, format: :short, nil_display: "—")
    return nil_display if time.blank?

    formatted = if format == :short
      l(time.in_time_zone(Current.time_zone), format: :short)
    else
      display_time(time)
    end

    label = report_date_basis_label(basis)
    label.present? ? "#{formatted} (#{label})" : formatted
  end

  def report_date_basis_label(basis)
    return nil if basis.blank?

    REPORT_DATE_BASIS_LABELS.fetch(basis.to_s) { basis.to_s.tr("_", " ").titleize }
  end

  def report_print_button(label: "Print")
    link_to label, "#", class: "ss-btn ss-btn-secondary ss-report-no-print", onclick: "window.print(); return false;"
  end
end
