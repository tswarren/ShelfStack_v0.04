# frozen_string_literal: true

module Buybacks
  class SaveProposal
    class Error < StandardError; end

    def self.call!(session:, actor:)
      new(session:, actor:).call!
    end

    def initialize(session:, actor:)
      @session = session
      @actor = actor
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Workstation is required to save a proposal." if session.workstation.blank?

      lines = session.buyback_lines.order(:line_number)
      raise Error, "At least one proposal line is required." if lines.empty?

      validate_lines!(lines)

      BuybackSession.transaction do
        BuybackNumberAssigner.call!(session: session) if session.buyback_number.blank?

        lines.each do |line|
          next unless proposal_line?(line)

          line.update!(status: "offered") if line.status == "priced"
        end

        session.update!(
          status: "quoted",
          proposal_saved_at: Time.current,
          quoted_at: Time.current,
          customer_decision_at: session.decision? ? nil : session.customer_decision_at
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "buyback.proposal.saved",
          auditable: session,
          details: { "buyback_number" => session.buyback_number }
        )
      end

      session.reload
    end

    private

    attr_reader :session, :actor

    def validate_lines!(lines)
      lines.each do |line|
        validate_line!(line)
      end
    end

    def validate_line!(line)
      if line.store_rejected?
        raise Error, "Line #{line.line_number} is missing reject reason." if line.buyback_reject_reason.blank?
        return
      end

      unless line.status.in?(%w[priced offered])
        raise Error, "Line #{line.line_number} must be priced before saving the proposal."
      end

      %i[proposed_resale_price_cents proposed_cash_offer_cents proposed_trade_credit_offer_cents].each do |field|
        raise Error, "Line #{line.line_number} is missing #{field}." if line.public_send(field).nil?
      end

      raise Error, "Line #{line.line_number} is missing condition." if line.product_condition.blank?
      raise Error, "Line #{line.line_number} is missing subdepartment." if line.sub_department.blank?
      raise Error, "Line #{line.line_number} is missing a sellable variant." if line.product_variant.blank?

      Eligibility.ensure_line_eligible!(line: line)
    end

    def proposal_line?(line)
      !line.store_rejected?
    end
  end
end
