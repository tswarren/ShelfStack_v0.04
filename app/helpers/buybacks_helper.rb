# frozen_string_literal: true

module BuybacksHelper
  include SetupFormatHelper

  def buyback_money(cents)
    format_cents(cents)
  end

  def buyback_status_label(status)
    {
      "draft" => "Draft",
      "quoted" => "Proposal saved",
      "decision" => "Customer decision",
      "completed" => "Completed",
      "cancelled" => "Cancelled",
      "voided" => "Voided"
    }.fetch(status.to_s, status.to_s.humanize)
  end

  def buyback_line_status_label(status)
    status.to_s.humanize
  end

  def buyback_outcome_label(outcome)
    return "—" if outcome.blank?

    outcome.to_s.humanize
  end

  def buyback_payout_options
    BuybackSession::PAYOUT_MODES.map { |mode| [mode.humanize, mode] }
  end

  def buyback_decision_options
    BuybackLine::OUTCOMES.map { |outcome| [buyback_outcome_label(outcome), outcome] }
  end

  def buyback_proposed_or_suggested(line, field)
    line.public_send("proposed_#{field}") || line.public_send("suggested_#{field}")
  end
end
