# frozen_string_literal: true

module Pos
  class StoredValueLookupsController < BaseController
    before_action :authorize_lookup!

    def show
      identifier = StoredValue::IdentifierCodec.lookup(params[:code])
      if identifier.blank?
        render json: { status: "not_found", message: "No active account found for that identifier." }, status: :not_found
        return
      end

      account = identifier.stored_value_account
      unless account_compatible?(account)
        render json: { status: "incompatible", message: "Account type is not compatible with this tender." }, status: :unprocessable_entity
        return
      end

      render json: {
        status: "found",
        account_id: account.id,
        identifier_id: identifier.id,
        account_type: account.account_type,
        display_value_masked: identifier.display_value_masked,
        holder_name: account.holder_name_snapshot || account.customer&.display_name,
        current_balance_cents: account.current_balance_cents,
        postable: account.postable?
      }
    end

    private

    def authorize_lookup!
      if params[:purpose] == "gift_card_sale"
        return if GiftCardSalePolicy.issue_permitted?(actor: current_user, store: current_store)

        render json: { status: "forbidden", message: "Not authorized." }, status: :forbidden
        return
      end

      permission = params[:tender_type] == "gift_card" ? "pos.tenders.gift_card" : "pos.tenders.store_credit"
      return if Authorization.allowed?(user: current_user, permission_key: permission, store: current_store)

      render json: { status: "forbidden", message: "Not authorized." }, status: :forbidden
    end

    def account_compatible?(account)
      tender_type = params[:tender_type].presence || "store_credit"
      StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type:)
    end
  end
end
