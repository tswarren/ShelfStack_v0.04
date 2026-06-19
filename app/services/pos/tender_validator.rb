# frozen_string_literal: true

module Pos
  class TenderValidator
    Error = Class.new(StandardError)

    CASH_REFUND_THRESHOLD_CENTS = 5_000

    def self.validate!(transaction, pos_authorization_id: nil)
      new(transaction, pos_authorization_id:).validate!
    end

    def initialize(transaction, pos_authorization_id: nil)
      @transaction = transaction
      @pos_authorization_id = pos_authorization_id
    end

    def validate!
      transaction.pos_tenders.each do |tender|
        unless PosTender::PHASE6_ALLOWED_TYPES.include?(tender.tender_type)
          raise Error, "Tender type #{tender.tender_type} is not enabled in Phase 6."
        end
      end

      tender_total = transaction.pos_tenders.sum(&:amount_cents)
      if tender_total != transaction.total_cents
        raise Error, "Tender total (#{tender_total}c) does not match transaction total (#{transaction.total_cents}c)."
      end

      cash_refund = transaction.pos_tenders.select { |t| t.tender_type == "cash" && t.amount_cents.negative? }.sum(&:amount_cents).abs
      return unless cash_refund > CASH_REFUND_THRESHOLD_CENTS

      authorization = PosAuthorization.find_by(id: pos_authorization_id)
      return if AuthorizationRequest.valid_for?(
        authorization: authorization,
        authorization_type: "cash_refund_over_threshold",
        pos_transaction: transaction
      )

      raise Error, "Cash refund exceeds threshold; supervisor authorization required."
    end

    private

    attr_reader :transaction, :pos_authorization_id
  end
end
