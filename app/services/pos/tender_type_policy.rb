# frozen_string_literal: true

module Pos
  class TenderTypePolicy
    BASE_TYPES = PosTender::PHASE6_ALLOWED_TYPES

    def self.allowed_types(transaction, actor:, store: nil)
      new(transaction:, actor:, store:).allowed_types
    end

    def self.allowed?(transaction, actor:, tender_type:, store: nil)
      allowed_types(transaction, actor:, store:).include?(tender_type.to_s)
    end

    def self.refund_transaction?(transaction)
      return true if transaction.total_cents.negative?
      return true if transaction.transaction_type.in?(%w[return exchange])
      return true if transaction.pos_transaction_lines.any? { |line| line.quantity.to_i.negative? }

      false
    end

    def self.refund_store_credit_permitted?(actor:, store:)
      return false if actor.blank?

      %w[
        pos.refunds.store_credit
        pos.tenders.store_credit
        pos.tenders.refund
        pos.transactions.complete
      ].any? do |permission_key|
        Authorization.allowed?(user: actor, permission_key: permission_key, store: store)
      end
    end

    def initialize(transaction:, actor:, store: nil)
      @transaction = transaction
      @actor = actor
      @store = store || transaction.store
    end

    def allowed_types
      types = BASE_TYPES.dup
      types << "store_credit" if store_credit_allowed?
      types << "gift_card" if gift_card_allowed?
      types.uniq
    end

    private

    attr_reader :transaction, :actor, :store

    def store_credit_allowed?
      if refund_transaction?
        refund_store_credit_allowed?
      else
        Authorization.allowed?(user: actor, permission_key: "pos.tenders.store_credit", store: store)
      end
    end

    def refund_store_credit_allowed?
      self.class.refund_store_credit_permitted?(actor:, store:)
    end

    def gift_card_allowed?
      Authorization.allowed?(user: actor, permission_key: "pos.tenders.gift_card", store: store)
    end

    def refund_transaction?
      self.class.refund_transaction?(transaction)
    end
  end
end
