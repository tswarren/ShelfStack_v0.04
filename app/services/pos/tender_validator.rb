# frozen_string_literal: true

module Pos
  class TenderValidator
    Error = Class.new(StandardError)

    CASH_REFUND_THRESHOLD_CENTS = 5_000

    def self.validate!(transaction, actor: nil, pos_authorization_id: nil)
      new(transaction, actor:, pos_authorization_id:).validate!
    end

    def initialize(transaction, actor: nil, pos_authorization_id: nil)
      @transaction = transaction
      @actor = actor
      @pos_authorization_id = pos_authorization_id
    end

    def validate!
      transaction.pos_tenders.settlement_rows.each do |tender|
        unless allowed_types.include?(tender.tender_type)
          raise Error, tender_type_disabled_message(tender.tender_type)
        end

        validate_stored_value_tender!(tender)
      end

      tender_total = transaction.pos_tenders.settlement_rows.sum(&:amount_cents)
      if tender_total != transaction.total_cents
        raise Error, "Tender total (#{tender_total}c) does not match transaction total (#{transaction.total_cents}c)."
      end

      validate_redemption_limits!

      cash_refund = transaction.pos_tenders.settlement_rows.select { |t| t.tender_type == "cash" && t.amount_cents.negative? }.sum(&:amount_cents).abs
      return unless cash_refund > CASH_REFUND_THRESHOLD_CENTS

      return if AuthorizationRequest.granted_for_transaction?(
        transaction: transaction,
        authorization_type: "cash_refund_over_threshold",
        pos_authorization_id: pos_authorization_id
      )

      raise Error, "Cash refund exceeds threshold; supervisor authorization required."
    end

    private

    attr_reader :transaction, :actor, :pos_authorization_id

    def allowed_types
      @allowed_types ||= if actor.present?
        TenderTypePolicy.allowed_types(transaction, actor:, store: transaction.store)
      else
        PosTender::PHASE6_ALLOWED_TYPES
      end
    end

    def tender_type_disabled_message(tender_type)
      return "Tender type #{tender_type} is not enabled." if actor.blank?

      if Pos::StoredValueTenderSupport.stored_value_tender?(tender_type) &&
          Pos::TenderTypePolicy.refund_transaction?(transaction)
        "Store credit refunds are not enabled for your role."
      elsif Pos::StoredValueTenderSupport.stored_value_tender?(tender_type)
        "Stored value tender #{tender_type} is not enabled for your role."
      else
        "Tender type #{tender_type} is not enabled."
      end
    end

    def validate_stored_value_tender!(tender)
      return unless tender.stored_value_tender?

      raise Error, "Stored value account is required." if tender.stored_value_account_id.blank? && transaction.customer_id.blank?

      if tender.redeem_tender?(transaction) && tender.stored_value_account.present?
        if tender.amount_cents > tender.stored_value_account.current_balance_cents
          raise Error, "Redemption exceeds available account balance."
        end
      end

      if tender.issue_tender?(transaction) && !tender.amount_cents.negative?
        raise Error, "Store credit refund amount must be negative."
      end

      if tender.redeem_tender?(transaction) && !tender.amount_cents.positive?
        raise Error, "Stored value redemption amount must be positive."
      end
    end

    def validate_redemption_limits!
      redeem_total = transaction.pos_tenders.settlement_rows.select { |t| t.redeem_tender?(transaction) }.sum(&:amount_cents)
      return if redeem_total.zero?

      other_total = transaction.pos_tenders.settlement_rows.reject(&:stored_value_tender?).sum(&:amount_cents)
      return unless transaction.total_cents.positive?

      if redeem_total + other_total > transaction.total_cents
        raise Error, "Stored value redemption exceeds transaction amount due."
      end
    end
  end
end
