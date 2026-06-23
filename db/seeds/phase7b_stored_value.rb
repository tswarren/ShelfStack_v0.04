# frozen_string_literal: true

module Seeds
  module Phase7bStoredValue
    REASON_CODES = [
      { reason_key: "manual_issue", name: "Manual Issue", description: "Manual credit issuance" },
      { reason_key: "manual_adjustment", name: "Manual Adjustment", description: "Balance correction" },
      { reason_key: "transfer", name: "Transfer", description: "Balance transfer between accounts" },
      { reason_key: "void_reversal", name: "Void Reversal", description: "Reversal of a ledger entry" },
      { reason_key: "promo", name: "Promotional Credit", description: "Promotional credit issuance" },
      { reason_key: "migration", name: "Legacy Migration", description: "Imported legacy balance" },
      { reason_key: "pos_return_credit", name: "POS Return Credit", description: "Credit issued from POS return or exchange" },
      { reason_key: "pos_gift_card_sale", name: "POS Gift Card Sale", description: "Gift card value issued from POS sale or reload" }
    ].freeze

    def self.seed!
      REASON_CODES.each do |attrs|
        StoredValueReasonCode.find_or_initialize_by(reason_key: attrs[:reason_key]).tap do |code|
          code.name = attrs[:name]
          code.description = attrs[:description]
          code.active = true
          code.save!
        end
      end
    end
  end
end
