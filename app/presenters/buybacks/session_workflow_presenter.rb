# frozen_string_literal: true

module Buybacks
  class SessionWorkflowPresenter
    Step = Data.define(:key, :label, :state)
    ActionState = Data.define(:enabled, :reason)
    NextAction = Data.define(:label, :kind, :anchor, :path, :method, :secondary_label, :secondary_path, :secondary_method)
    QueueSummary = Data.define(
      :total_count,
      :needs_match_count,
      :needs_price_count,
      :ready_for_proposal_count,
      :decision_needed_count,
      :priced_repriced_count
    )

    STEPS = [
      { key: :seller, label: "Seller" },
      { key: :intake, label: "Intake" },
      { key: :price_items, label: "Price items" },
      { key: :proposal, label: "Proposal" },
      { key: :customer_decision, label: "Customer decision" },
      { key: :payout, label: "Payout" },
      { key: :complete, label: "Complete" }
    ].freeze

    WORKFLOW_FILTER_STATES = %w[
      all
      needs_match
      needs_price
      ready_for_proposal
      customer_decision_needed
      accepted
      declined
      donated
    ].freeze

    def initialize(session:, lines:, proposal: nil, decision_totals: nil, seller_requirements: [], register_session: nil)
      @session = session
      @lines = lines.to_a
      @proposal = proposal
      @decision_totals = decision_totals
      @seller_requirements = seller_requirements
      @register_session = register_session
    end

    attr_reader :session, :lines, :proposal, :decision_totals, :seller_requirements, :register_session

    def steps
      @steps ||= STEPS.map do |step|
        Step.new(key: step[:key], label: step[:label], state: step_state(step[:key]))
      end
    end

    def current_step_key
      steps.find { |s| s.state == :current }&.key || infer_current_step_key
    end

    def next_action
      @next_action ||= build_next_action
    end

    def queue_summary
      @queue_summary ||= QueueSummary.new(
        total_count: active_lines.size,
        needs_match_count: count_by_workflow_state(:needs_match),
        needs_price_count: count_by_workflow_state(:needs_price),
        ready_for_proposal_count: count_by_workflow_state(:ready_for_proposal),
        decision_needed_count: count_by_workflow_state(:customer_decision_needed),
        priced_repriced_count: lines.count { |l| l.status == "priced" && session.decision? }
      )
    end

    def intake_queue_text
      parts = ["#{queue_summary.total_count} items"]
      parts << "#{queue_summary.needs_match_count} need match" if queue_summary.needs_match_count.positive?
      parts << "#{queue_summary.needs_price_count} need price" if queue_summary.needs_price_count.positive?
      parts << "#{queue_summary.ready_for_proposal_count} ready for proposal" if queue_summary.ready_for_proposal_count.positive?
      parts << "#{queue_summary.decision_needed_count} need decision" if queue_summary.decision_needed_count.positive?
      parts.join(" · ")
    end

    def footer_summary_text
      if session.decision? || session.completed?
        return decision_footer_text if decision_totals.present?

        intake_queue_text
      else
        proposal_footer_text
      end
    end

    def action_state(action_key)
      case action_key.to_sym
      when :save_proposal then save_proposal_state
      when :open_decision then open_decision_state
      when :accept_all then batch_decision_state
      when :decline_all then batch_decision_state
      when :donate_declined then donate_declined_state
      when :complete then complete_state
      when :save_payout then save_payout_state
      else
        ActionState.new(enabled: true, reason: nil)
      end
    end

    def line_workflow_state(line)
      return :store_rejected if line.store_rejected?
      return :accepted if line.outcome == "accepted_by_customer"
      return :declined if line.outcome == "declined_by_customer"
      return :donated if line.outcome == "donated_by_customer"
      return :recycled if line.outcome == "recycle_with_permission"

      case line.status
      when "pending" then :needs_match
      when "resolved" then :needs_price
      when "priced" then session.decision? ? :ready_for_proposal : :ready_for_proposal
      when "offered"
        session.decision? ? :customer_decision_needed : :ready_for_proposal
      when "decided"
        :customer_decision_needed
      when "posted" then :accepted
      when "voided" then :declined
      else
        :needs_match
      end
    end

    def next_line
      priority = %i[needs_match needs_price ready_for_proposal customer_decision_needed]
      priority.each do |state|
        match = active_lines.find { |line| line_workflow_state(line) == state }
        return match if match.present?
      end
      nil
    end

    def next_line_id
      next_line&.id
    end

    def proposal_stale?
      return false unless session.proposal_printed_at.present?

      stale_line = lines.any? do |line|
        next if line.store_rejected?

        line.updated_at > session.proposal_printed_at
      end
      stale_line || session.proposal_saved_at.to_i > session.proposal_printed_at.to_i
    end

    def repriced_lines_blocking_batch?
      session.decision? && lines.any? { |l| l.status == "priced" }
    end

    def all_lines_decided?
      active_lines.all? { |l| l.status == "decided" || l.store_rejected? }
    end

    def seller_requirements_met?
      seller_requirements.empty?
    end

    private

    def active_lines
      @active_lines ||= lines.reject(&:store_rejected?)
    end

    def count_by_workflow_state(state)
      active_lines.count { |line| line_workflow_state(line) == state }
    end

    def infer_current_step_key
      return :complete if session.completed? || session.voided?
      return :payout if session.decision? && all_lines_decided? && session.payout_mode.blank?
      return :customer_decision if session.decision?
      return :proposal if session.quoted?
      return :price_items if queue_summary.needs_match_count.positive? || queue_summary.needs_price_count.positive?
      return :intake if session.draft? && lines.empty?

      :seller
    end

    def step_state(key)
      return :complete if session.completed? || session.voided? || session.cancelled?

      case key
      when :seller
        session.customer.present? ? :complete : :current
      when :intake
        return :complete unless session.draft?
        return :current if lines.empty?

        queue_summary.needs_match_count.positive? ? :current : :complete
      when :price_items
        return :future if session.quoted? || session.decision?
        return :complete if session.draft? && pricing_complete?

        session.draft? ? :current : :future
      when :proposal
        return :complete if session.decision? || session.quoted?
        return :current if session.draft? && pricing_complete?

        :future
      when :customer_decision
        return :complete if session.decision? && all_lines_decided?
        return :current if session.decision? || session.quoted?

        :future
      when :payout
        return :complete if session.completed?
        return :current if session.decision? && all_lines_decided? && session.payout_mode.present?
        return :blocked if session.decision? && all_lines_decided? && session.payout_mode.blank?

        :future
      when :complete
        return :complete if session.completed?
        return :current if session.decision? && all_lines_decided? && session.payout_mode.present?

        :future
      else
        :future
      end
    end

    def pricing_complete?
      active_lines.any? && queue_summary.needs_match_count.zero? && queue_summary.needs_price_count.zero?
    end

    def build_next_action
      if session.completed?
        return NextAction.new(label: "Buyback completed", kind: :info, anchor: nil, path: nil, method: nil,
                              secondary_label: nil, secondary_path: nil, secondary_method: nil)
      end

      if session.draft? && lines.empty?
        return NextAction.new(label: "Scan or add item", kind: :anchor, anchor: "intake-panel",
                              path: nil, method: nil, secondary_label: nil, secondary_path: nil, secondary_method: nil)
      end

      if session.draft? && (queue_summary.needs_match_count.positive? || queue_summary.needs_price_count.positive?)
        anchor = next_line_id ? "line-#{next_line_id}" : "work-items-panel"
        return NextAction.new(label: "Price remaining items", kind: :anchor, anchor: anchor,
                              path: nil, method: nil, secondary_label: nil, secondary_path: nil, secondary_method: nil)
      end

      if session.draft? && pricing_complete?
        state = save_proposal_state
        return NextAction.new(
          label: "Save proposal",
          kind: state.enabled ? :path : :disabled,
          anchor: "proposal-panel",
          path: nil,
          method: :patch,
          secondary_label: nil,
          secondary_path: nil,
          secondary_method: nil
        )
      end

      if session.quoted? && !session.decision?
        return NextAction.new(
          label: "Open customer decisions",
          kind: open_decision_state.enabled ? :path : :disabled,
          anchor: "decision-panel",
          path: nil,
          method: :patch,
          secondary_label: "Print proposal",
          secondary_path: nil,
          secondary_method: :get
        )
      end

      if session.decision? && !all_lines_decided?
        return NextAction.new(label: "Record customer decisions", kind: :anchor, anchor: "decision-panel",
                              path: nil, method: nil, secondary_label: nil, secondary_path: nil, secondary_method: nil)
      end

      if session.decision? && all_lines_decided? && session.payout_mode.blank?
        return NextAction.new(label: "Select payout method", kind: :anchor, anchor: "payout-panel",
                              path: nil, method: nil, secondary_label: nil, secondary_path: nil, secondary_method: nil)
      end

      if session.decision? && all_lines_decided? && session.payout_mode.present?
        state = complete_state
        return NextAction.new(
          label: "Complete buyback",
          kind: state.enabled ? :path : :disabled,
          anchor: nil,
          path: nil,
          method: :patch,
          secondary_label: nil,
          secondary_path: nil,
          secondary_method: nil
        )
      end

      NextAction.new(label: "Continue buyback", kind: :anchor, anchor: "work-items-panel",
                     path: nil, method: nil, secondary_label: nil, secondary_path: nil, secondary_method: nil)
    end

    def proposal_footer_text
      cash = active_lines.sum { |l| (l.proposed_cash_offer_cents || l.suggested_cash_offer_cents).to_i }
      trade = active_lines.sum { |l| (l.proposed_trade_credit_offer_cents || l.suggested_trade_credit_offer_cents).to_i }
      "#{queue_summary.total_count} lines · #{queue_summary.needs_match_count} need match · Cash #{format_money(cash)} · Trade #{format_money(trade)}"
    end

    def decision_footer_text
      return intake_queue_text unless decision_totals

      cash = format_money(decision_totals.accepted_cash_cents)
      trade = format_money(decision_totals.accepted_trade_credit_cents)
      "Accepted #{active_lines.count { |l| l.outcome == 'accepted_by_customer' }} · " \
        "Declined #{decision_totals.declined_count} · Donated #{decision_totals.donation_count} · " \
        "Cash #{cash} · Trade #{trade}"
    end

    def format_money(cents)
      "$#{'%.2f' % (cents.to_i / 100.0)}"
    end

    def save_proposal_state
      if !session.draft?
        return ActionState.new(enabled: false, reason: "Proposal is already saved.")
      end
      if lines.empty?
        return ActionState.new(enabled: false, reason: "Add at least one item before saving the proposal.")
      end
      if queue_summary.needs_match_count.positive?
        return ActionState.new(enabled: false, reason: "#{queue_summary.needs_match_count} lines still need match.")
      end
      if queue_summary.needs_price_count.positive?
        return ActionState.new(enabled: false, reason: "#{queue_summary.needs_price_count} lines still need pricing.")
      end
      if session.workstation.blank?
        return ActionState.new(enabled: false, reason: "Workstation is required to save a proposal.")
      end

      ActionState.new(enabled: true, reason: nil)
    end

    def open_decision_state
      return ActionState.new(enabled: false, reason: "Save proposal first.") unless session.quoted? || session.decision?
      return ActionState.new(enabled: false, reason: "Customer decision stage is already open.") if session.decision?

      ActionState.new(enabled: true, reason: nil)
    end

    def batch_decision_state
      if repriced_lines_blocking_batch?
        return ActionState.new(enabled: false, reason: "Repriced lines must be saved back into the proposal before batch decisions.")
      end
      unless session.decision?
        return ActionState.new(enabled: false, reason: "Open customer decisions first.")
      end
      if lines.none? { |l| l.status == "offered" }
        return ActionState.new(enabled: false, reason: "No offered lines are waiting for customer decision.")
      end

      ActionState.new(enabled: true, reason: nil)
    end

    def donate_declined_state
      unless session.decision?
        return ActionState.new(enabled: false, reason: "Open customer decisions first.")
      end
      unless lines.any? { |l| l.outcome == "declined_by_customer" }
        return ActionState.new(enabled: false, reason: "No declined lines to mark as donated.")
      end

      ActionState.new(enabled: true, reason: nil)
    end

    def save_payout_state
      return ActionState.new(enabled: false, reason: "Record all customer decisions first.") unless all_lines_decided?

      ActionState.new(enabled: true, reason: nil)
    end

    def complete_state
      unless session.decision?
        return ActionState.new(enabled: false, reason: "Complete is only available during customer decision stage.")
      end
      unless all_lines_decided?
        undecided = count_by_workflow_state(:customer_decision_needed)
        return ActionState.new(enabled: false, reason: "#{undecided} lines still need customer decision.")
      end
      if session.payout_mode.blank?
        return ActionState.new(enabled: false, reason: "Select a payout method first.")
      end
      unless seller_requirements_met?
        return ActionState.new(enabled: false, reason: "Seller requirements must be complete before completion.")
      end
      if session.payout_mode == "cash" && register_session.blank?
        return ActionState.new(enabled: false, reason: "Open a register session before completing a cash payout.")
      end
      if blocking_unfinished_lines?
        return ActionState.new(enabled: false, reason: "All active lines must be resolved, priced, and decided.")
      end

      ActionState.new(enabled: true, reason: nil)
    end

    def blocking_unfinished_lines?
      lines.any? { |l| l.status.in?(%w[pending resolved priced offered]) && l.outcome.blank? }
    end
  end
end
