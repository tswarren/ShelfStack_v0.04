# frozen_string_literal: true

module Pos
  class StoredValueBalanceController < BaseController
    before_action :authorize_balance_inquiry!

    def show
    end

    private

    def authorize_balance_inquiry!
      return if balance_inquiry_permitted?

      redirect_to pos_root_path, alert: "You are not authorized to check stored value balances."
    end

    def balance_inquiry_permitted?
      %w[pos.tenders.gift_card pos.tenders.store_credit pos.gift.cards.issue].any? do |permission_key|
        Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)
      end
    end
  end
end
