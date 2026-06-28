# frozen_string_literal: true

module Pos
  module StoredValueTenderSupport
    STORED_VALUE_TENDER_TYPES = %w[store_credit gift_card].freeze
    STORED_VALUE_PLACEHOLDER_TYPE = "stored_value"
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

    def stored_value_placeholder?(tender_type)
      tender_type.to_s == STORED_VALUE_PLACEHOLDER_TYPE
    end

    def resolve_tender_type_for_account(account)
      if GIFT_CARD_ACCOUNT_TYPES.include?(account.account_type)
        "gift_card"
      else
        "store_credit"
      end
    end

    def stored_value_type_label(tender_type)
      case tender_type.to_s
      when "gift_card"
        "Gift card"
      when "store_credit"
        "Store credit"
      when STORED_VALUE_PLACEHOLDER_TYPE
        "Stored value"
      else
        tender_type.to_s.humanize
      end
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

    def capped_redeem_amount_cents(transaction:, tender_type:, amount_cents:, stored_value_account_id: nil, account: nil)
      return amount_cents unless stored_value_tender?(tender_type)
      return amount_cents if Pos::TenderTypePolicy.refund_transaction?(transaction)
      return amount_cents unless amount_cents.to_i.positive?

      account ||= StoredValueAccount.find_by(id: stored_value_account_id) if stored_value_account_id.present?
      return amount_cents if account.blank?

      [ amount_cents.to_i, account.current_balance_cents ].min
    end
  end
end
