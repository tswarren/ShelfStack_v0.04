# frozen_string_literal: true

module Pos
  class GiftCardSalePolicy
    PERMISSION_KEY = "pos.gift_cards.issue"

    def self.issue_permitted?(actor:, store:)
      Authorization.allowed?(user: actor, permission_key: PERMISSION_KEY, store: store)
    end
  end
end
