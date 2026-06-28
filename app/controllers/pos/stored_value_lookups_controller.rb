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

      resolved_tender_type = StoredValueTenderSupport.resolve_tender_type_for_account(account)
      if params[:tender_type] == StoredValueTenderSupport::STORED_VALUE_PLACEHOLDER_TYPE &&
          !authorized_for_tender_type?(resolved_tender_type)
        render json: { status: "forbidden", message: "#{StoredValueTenderSupport.stored_value_type_label(resolved_tender_type)} tender is not enabled for your role." }, status: :forbidden
        return
      end

      render json: {
        status: "found",
        account_id: account.id,
        identifier_id: identifier.id,
        account_type: account.account_type,
        resolved_tender_type: resolved_tender_type,
        resolved_tender_type_label: StoredValueTenderSupport.stored_value_type_label(resolved_tender_type),
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

      if params[:purpose] == "balance_inquiry"
        return if balance_inquiry_permitted?

        render json: { status: "forbidden", message: "Not authorized." }, status: :forbidden
        return
      end

      permission = params[:tender_type] == "gift_card" ? "pos.tenders.gift_card" : "pos.tenders.store_credit"
      if params[:tender_type] == Pos::StoredValueTenderSupport::STORED_VALUE_PLACEHOLDER_TYPE
        return if settlement_stored_value_lookup_permitted?
      elsif Authorization.allowed?(user: current_user, permission_key: permission, store: current_store)
        return
      end

      render json: { status: "forbidden", message: "Not authorized." }, status: :forbidden
    end

    def settlement_stored_value_lookup_permitted?
      %w[pos.tenders.gift_card pos.tenders.store_credit].any? do |permission_key|
        Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)
      end
    end

    def authorized_for_tender_type?(tender_type)
      permission = tender_type == "gift_card" ? "pos.tenders.gift_card" : "pos.tenders.store_credit"
      Authorization.allowed?(user: current_user, permission_key: permission, store: current_store)
    end

    def balance_inquiry_permitted?
      %w[pos.tenders.gift_card pos.tenders.store_credit pos.gift.cards.issue].any? do |permission_key|
        Authorization.allowed?(user: current_user, permission_key: permission_key, store: current_store)
      end
    end

    def account_compatible?(account)
      if params[:purpose] == "balance_inquiry"
        return StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type: "gift_card") ||
          StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type: "store_credit")
      end

      tender_type = params[:tender_type].presence || "store_credit"
      if tender_type == StoredValueTenderSupport::STORED_VALUE_PLACEHOLDER_TYPE
        return StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type: "gift_card") ||
          StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type: "store_credit")
      end

      StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type:)
    end
  end
end
