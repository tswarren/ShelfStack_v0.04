# frozen_string_literal: true

module Buybacks
  class CompleteSession
    class Error < StandardError; end

    def self.call!(session:, actor:, register_session: nil)
      new(session:, actor:, register_session:).call!
    end

    def initialize(session:, actor:, register_session: nil)
      @session = session
      @actor = actor
      @register_session = register_session
    end

    def call!
      raise Error, "Session is not editable." unless session.editable?
      raise Error, "Payout mode is required." if session.payout_mode.blank?
      raise Error, "Workstation is required." if session.workstation.blank?

      SellerRequirements.validate!(customer: session.customer)
      validate_lines!

      BuybackSession.transaction do
        session.workstation ||= Current.workstation
        session.business_date ||= register_session&.business_date || Date.current
        BuybackNumberAssigner.call!(session: session)

        case session.payout_mode
        when "cash"
          post_cash_payout!
        when "trade_credit"
          post_trade_credit_payout!
        when "no_value_donation"
          # no payout records
        else
          raise Error, "Invalid payout mode."
        end

        PostInventory.call(session:, posted_by_user: actor)
        snapshot_seller!
        totals = compute_totals

        session.update!(
          status: "completed",
          completed_at: Time.current,
          completed_by_user: actor,
          accepted_payout_cents: totals[:payout_cents],
          total_cash_offer_cents: totals[:cash_offer_cents],
          total_trade_credit_offer_cents: totals[:trade_credit_offer_cents]
        )

        AuditEvents.record!(
          actor: actor,
          event_name: "buyback.session.completed",
          auditable: session,
          details: { "buyback_number" => session.buyback_number, "payout_mode" => session.payout_mode }
        )
      end

      session.reload
    end

    private

    attr_reader :session, :actor, :register_session

    def validate_lines!
      posting_lines = session.buyback_lines.select(&:accepted_for_posting?)
      raise Error, "At least one accepted or donated line is required." if posting_lines.empty?

      posting_lines.each { |line| Eligibility.ensure_line_eligible!(line: line) }
      validate_payout_alignment!(posting_lines)
    end

    def validate_payout_alignment!(lines)
      case session.payout_mode
      when "cash"
        lines.each do |line|
          raise Error, "Cash payout requires accepted_for_cash lines." unless line.outcome == "accepted_for_cash"
        end
      when "trade_credit"
        lines.each do |line|
          raise Error, "Trade credit payout requires accepted_for_trade_credit lines." unless line.outcome == "accepted_for_trade_credit"
        end
      when "no_value_donation"
        lines.each do |line|
          raise Error, "Donation payout requires accepted_as_donation lines." unless line.outcome == "accepted_as_donation"
          raise Error, "Donation lines must have zero offer." if line.accepted_offer_cents.to_i.positive?
        end
      end
    end

    def post_cash_payout!
      raise Error, "Open register session is required for cash payout." unless register_session&.open?

      amount = session.buyback_lines.select(&:accepted_for_posting?).sum { |l| l.accepted_offer_cents.to_i }
      raise Error, "Cash payout amount must be positive." unless amount.positive?

      movement = register_session.pos_cash_movements.create!(
        store: session.store,
        movement_type: "paid_out",
        amount_cents: amount,
        reason_code: "used_buyback",
        recorded_at: Time.current,
        recorded_by_user: actor,
        source: session
      )
      session.update!(pos_register_session: register_session, pos_cash_movement: movement)

      AuditEvents.record!(actor: actor, event_name: "buyback.paid.cash", auditable: session, source: movement)
    end

    def post_trade_credit_payout!
      amount = session.buyback_lines.select(&:accepted_for_posting?).sum { |l| l.accepted_offer_cents.to_i }
      raise Error, "Trade credit payout amount must be positive." unless amount.positive?

      account = find_or_create_trade_credit_account!
      reason = StoredValueReasonCode.find_by!(reason_key: "buyback_trade_credit_issue")
      entry = StoredValue::Issue.call(
        account: account,
        store: session.store,
        actor: actor,
        amount_cents: amount,
        reason_code: reason,
        notes: "Buyback #{session.buyback_number}"
      )

      identifier = account.stored_value_identifiers.active_records.first
      identifier ||= StoredValue::CreateIdentifier.call(
        account: account,
        actor: actor,
        identifier_type: "generated"
      )

      session.update!(stored_value_account: account, stored_value_ledger_entry: entry)
      session.instance_variable_set(:@issued_identifier, identifier)

      AuditEvents.record!(actor: actor, event_name: "buyback.paid.trade_credit", auditable: session, source: entry)
    end

    def find_or_create_trade_credit_account!
      account = StoredValueAccount.active_records.find_by(
        customer_id: session.customer_id,
        issuing_store_id: session.store_id,
        account_type: "trade_credit"
      )
      return account if account.present?

      StoredValueAccount.create!(
        customer: session.customer,
        issuing_store: session.store,
        account_type: "trade_credit",
        holder_name_snapshot: session.customer.display_name,
        active: true
      )
    end

    def snapshot_seller!
      customer = session.customer
      session.update!(
        seller_display_name_snapshot: customer.display_name,
        seller_first_name_snapshot: customer.first_name,
        seller_last_name_snapshot: customer.last_name,
        seller_address_line1_snapshot: customer.address_line1,
        seller_address_line2_snapshot: customer.address_line2,
        seller_city_snapshot: customer.city,
        seller_region_code_snapshot: customer.region_code,
        seller_postal_code_snapshot: customer.postal_code,
        seller_country_code_snapshot: customer.country_code,
        seller_phone_snapshot: customer.phone,
        seller_email_snapshot: customer.email
      )
    end

    def compute_totals
      lines = session.buyback_lines.select(&:accepted_for_posting?)
      {
        payout_cents: lines.sum { |l| l.accepted_offer_cents.to_i },
        cash_offer_cents: lines.sum { |l| l.suggested_cash_offer_cents.to_i },
        trade_credit_offer_cents: lines.sum { |l| l.suggested_trade_credit_offer_cents.to_i }
      }
    end
  end
end
