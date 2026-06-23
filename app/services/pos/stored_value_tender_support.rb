# frozen_string_literal: true

module Pos
  module StoredValueTenderSupport
    STORED_VALUE_TENDER_TYPES = %w[store_credit gift_card].freeze
    STORE_CREDIT_ACCOUNT_TYPES = %w[
      merchandise_credit
      manual_store_credit
      trade_credit
      promo_credit
      legacy_credit
    ].freeze
    GIFT_CARD_ACCOUNT_TYPES = %w[gift_card].freeze

    module_function

    def stored_value_tender?(tender_type)
      STORED_VALUE_TENDER_TYPES.include?(tender_type.to_s)
    end

    def account_types_for_tender(tender_type)
      case tender_type.to_s
      when "store_credit"
        STORE_CREDIT_ACCOUNT_TYPES
      when "gift_card"
        GIFT_CARD_ACCOUNT_TYPES
      else
        []
      end
    end

    def default_account_type_for_tender(tender_type)
      case tender_type.to_s
      when "store_credit"
        "merchandise_credit"
      when "gift_card"
        "gift_card"
      end
    end

    def account_compatible_with_tender?(account:, tender_type:)
      account_types_for_tender(tender_type).include?(account.account_type)
    end

    def issue_tender?(transaction:, tender:)
      stored_value_tender?(tender.tender_type) &&
        Pos::TenderTypePolicy.refund_transaction?(transaction) &&
        tender.amount_cents.negative?
    end

    def redeem_tender?(transaction:, tender:)
      stored_value_tender?(tender.tender_type) &&
        !Pos::TenderTypePolicy.refund_transaction?(transaction) &&
        tender.amount_cents.positive?
    end
  end
end
