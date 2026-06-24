# frozen_string_literal: true

module BuybacksHelper
  include SetupFormatHelper

  LINE_WORKFLOW_LABELS = {
    needs_match: "Needs match",
    needs_price: "Needs price",
    ready_for_proposal: "Ready for proposal",
    customer_decision_needed: "Customer decision needed",
    accepted: "Customer accepted",
    declined: "Customer declined",
    donated: "Customer donated",
    store_rejected: "Store rejected",
    recycled: "Recycle with permission"
  }.freeze

  WORKFLOW_FILTER_LABELS = {
    "all" => "All",
    "needs_match" => "Needs match",
    "needs_price" => "Needs price",
    "ready_for_proposal" => "Ready for proposal",
    "customer_decision_needed" => "Customer decision needed",
    "accepted" => "Accepted",
    "declined" => "Declined",
    "donated" => "Donated"
  }.freeze

  def buyback_money(cents)
    format_cents(cents)
  end

  def buyback_proposal_datetime(session, time)
    return "—" if time.blank?

    l(time.in_time_zone(session.store.time_zone), format: :short)
  end

  def buyback_proposal_store_lines(store)
    lines = []
    lines << store.name if store.name.present?
    address = [store.address_line1, store.address_line2].compact_blank.join(", ")
    lines << address if address.present?
    city_line = [store.city, store.region_code, store.postal_code].compact_blank.join(", ")
    lines << city_line if city_line.present?
    lines << store.phone if store.phone.present?
    lines
  end

  def buyback_line_identifier(line)
    line.identifier_entered.presence || "—"
  end

  def buyback_line_reject_reason(line)
    line.buyback_reject_reason&.name.presence || line.notes.presence || "—"
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

  def buyback_line_workflow_label(line, workflow: nil)
    state = workflow&.line_workflow_state(line) || infer_line_workflow_state(line)
    LINE_WORKFLOW_LABELS.fetch(state, state.to_s.humanize)
  end

  def buyback_line_status_badge(line, workflow: nil)
    state = workflow&.line_workflow_state(line) || infer_line_workflow_state(line)
    css_class = buyback_line_workflow_badge_class(state)
    tag.span(buyback_line_workflow_label(line, workflow: workflow), class: "ss-status-badge #{css_class}")
  end

  def buyback_line_workflow_badge_class(state)
    case state.to_sym
    when :needs_match, :needs_price
      "status-warning"
    when :ready_for_proposal, :customer_decision_needed
      "status-draft"
    when :accepted
      "status-active"
    when :declined, :store_rejected, :recycled
      "status-cancelled"
    when :donated
      "status-submitted"
    else
      "status-inactive"
    end
  end

  def buyback_line_workflow_state(line, workflow:)
    workflow.line_workflow_state(line).to_s
  end

  def buyback_payout_options
    BuybackSession::PAYOUT_MODES.map { |mode| [mode.humanize, mode] }
  end

  def buyback_payout_card_label(mode)
    {
      "cash" => "Pay cash",
      "trade_credit" => "Issue trade credit",
      "no_value_donation" => "Complete as no-value donation"
    }.fetch(mode, mode.humanize)
  end

  def buyback_decision_options
    BuybackLine::OUTCOMES.map { |outcome| [buyback_outcome_label(outcome), outcome] }
  end

  def buyback_proposed_or_suggested(line, field)
    proposed = line.public_send("proposed_#{field}")
    return proposed if proposed.present?

    suggested = line.public_send("suggested_#{field}")
    return suggested if suggested.present?

    pricing = buyback_resolved_pricing(line)
    return nil unless pricing

    case field.to_s
    when "resale_price_cents" then pricing.resale_price_cents
    when "cash_offer_cents" then pricing.cash_offer_cents
    when "trade_credit_offer_cents" then pricing.trade_credit_offer_cents
    end
  end

  def buyback_resolved_pricing(line)
    return nil if line.product_condition.blank? || line.sub_department.blank?

    if line.suggested_resale_price_cents.present? || line.suggested_cash_offer_cents.present? ||
       line.suggested_trade_credit_offer_cents.present?
      return Buybacks::PriceLine::Result.new(
        resale_price_cents: line.suggested_resale_price_cents.to_i,
        cash_offer_cents: line.suggested_cash_offer_cents.to_i,
        trade_credit_offer_cents: line.suggested_trade_credit_offer_cents.to_i,
        pricing_rule: line.buyback_pricing_rule
      )
    end

    Buybacks::PriceLine.call(line: line)
  end

  def buyback_workflow_filter_label(filter)
    WORKFLOW_FILTER_LABELS.fetch(filter.to_s, filter.to_s.humanize)
  end

  def buyback_workflow_step_class(step)
    case step.state
    when :complete then "ss-buyback-step--complete"
    when :current then "ss-buyback-step--current"
    when :blocked then "ss-buyback-step--blocked"
    else "ss-buyback-step--future"
    end
  end

  def buyback_workflow_step_marker(step)
    case step.state
    when :complete then "✓"
    when :current then "●"
    when :blocked then "!"
    else "○"
    end
  end

  def buyback_action_button(path:, method:, label:, enabled:, reason: nil, **options)
    css = ["ss-btn", options.delete(:class)].compact.join(" ")
    data = options.delete(:data) || {}
    if enabled
      button_to label, path, method: method, class: css, data: data, **options
    else
      tag.div(class: "ss-buyback-action-disabled") do
        safe_join([
          tag.button(label, class: "#{css} ss-btn--disabled", disabled: true, type: "button"),
          (tag.p(reason, class: "ss-hint") if reason.present?)
        ].compact)
      end
    end
  end

  private

  def infer_line_workflow_state(line)
    return :store_rejected if line.store_rejected?
    return :accepted if line.outcome == "accepted_by_customer"
    return :declined if line.outcome == "declined_by_customer"
    return :donated if line.outcome == "donated_by_customer"
    return :recycled if line.outcome == "recycle_with_permission"

    case line.status
    when "pending" then :needs_match
    when "resolved" then :needs_price
    when "priced", "offered" then :ready_for_proposal
    when "decided" then :customer_decision_needed
    else :needs_match
    end
  end
end
