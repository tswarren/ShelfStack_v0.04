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
    link_to label, "#",
      class: "#{ss_button_classes(variant: :secondary)} ss-report-no-print",
      onclick: "window.print(); return false;"
  end

  def report_back_link(label: "Back to reports", path: reports_root_path)
    render("shared/ui/button",
           label: label,
           variant: :tertiary,
           url: path,
           class: "ss-report-no-print")
  end

  def report_standard_actions(export_url: nil, back_path: reports_root_path, back_label: "Back to reports")
    safe_join([
      report_print_button,
      (render("reports/shared/export_action", url: export_url) if export_url.present?),
      (report_back_link(label: back_label, path: back_path) if back_path.present?)
    ].compact)
  end

  def report_csv_link(path, label: "Export CSV")
    render("shared/ui/button",
           label: label,
           variant: :secondary,
           url: path,
           class: "ss-report-no-print",
           data: { turbo: false })
  end

  def reports_nav_visible?
    Reports::Registry.nav_visible?(user: current_user, store: current_store)
  end

  def report_session_options(sessions)
    sessions.map do |session|
      label = [
        session.workstation.name,
        session.business_date,
        session.status,
        l(session.opened_at.in_time_zone(session.store.time_zone), format: :short)
      ].join(" · ")
      [ label, session.id ]
    end
  end

  def report_register_summary_subtitle(report)
    session = report.session
    store = report.scope.store
    [
      store.name,
      "Register #{session.workstation.workstation_number}",
      session.business_date,
      "Opened #{format_report_date(session.opened_at, basis: nil)}"
    ].join(" · ")
  end

  def report_signed_money(cents)
    return format_report_money(0) if cents.to_i.zero?

    format_report_money(cents, signed: cents.negative?)
  end
end
