# frozen_string_literal: true

module PosReportsHelper
  def pos_store_local_time(time, format: :short)
    return "—" if time.blank?

    l(time.in_time_zone(pos_store.time_zone), format: format)
  end

  def pos_report_signed_money(cents)
    return pos_money(0) if cents.to_i.zero?

    if cents.negative?
      content_tag(:span, "(#{pos_money(cents.abs)})", class: "ss-pos-report-money is-negative")
    else
      content_tag(:span, pos_money(cents), class: "ss-pos-report-money")
    end
  end

  def pos_report_filter_type
    params[:filter_type].presence || "register_session"
  end

  def pos_report_session_options(sessions)
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

  def pos_register_summary_subtitle(report)
    session = report.session
    store = report.scope.store
    [
      store.name,
      "Register #{session.workstation.workstation_number}",
      session.business_date,
      "Opened #{pos_store_local_time(session.opened_at)}"
    ].join(" · ")
  end

  def pos_report_mix_value(row)
    if row.units_sold.present?
      row.units_sold.to_s
    elsif row.count.present? && !row.amount_cents.to_i.zero?
      safe_join([ row.count.to_s, pos_report_signed_money(row.amount_cents) ], " ")
    elsif row.count.present?
      row.count.to_s
    else
      pos_report_signed_money(row.amount_cents)
    end
  end

  def pos_report_exceptions_summary(exceptions)
    parts = [
      "#{exceptions.void_count} #{'void'.pluralize(exceptions.void_count)} (#{pos_money(exceptions.void_cents)})",
      "#{exceptions.no_receipt_return_count} #{'no-receipt return'.pluralize(exceptions.no_receipt_return_count)}",
      "#{exceptions.auth_override_count} #{'auth override'.pluralize(exceptions.auth_override_count)}"
    ]
    parts.join(" · ")
  end

  def pos_report_breakdown_discounts(metrics)
    pos_report_signed_money(Pos::ReportTransactionMetrics.total_discounts_cents(metrics))
  end
end
