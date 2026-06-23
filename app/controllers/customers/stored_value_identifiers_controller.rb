# frozen_string_literal: true

module Customers
  class StoredValueIdentifiersController < BaseController
    before_action :set_account
    before_action :set_identifier, only: %i[reveal replace deactivate]
    before_action -> { authorize!("stored_value.identifiers.create") }, only: :create
    before_action -> { authorize!("stored_value.identifiers.view_full") }, only: :reveal
    before_action -> { authorize!("stored_value.identifiers.replace") }, only: :replace
    before_action -> { authorize!("stored_value.identifiers.deactivate") }, only: :deactivate

    def create
      identifier_type = params[:identifier_type].presence || "generated"
      identifier = StoredValue::CreateIdentifier.call(
        account: @account,
        actor: current_user,
        identifier_type: identifier_type,
        raw_value: params[:raw_value]
      )
      flash_generated_identifier!(identifier) if identifier_type == "generated"
      redirect_to customers_stored_value_account_path(@account), notice: "Identifier created."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def reveal
      value = StoredValue::RevealIdentifier.call(identifier: @identifier, actor: current_user)
      store_revealed_identifier_flash!(@identifier, value)
      redirect_to customers_stored_value_account_path(@account), notice: "Full identifier revealed below."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def replace
      replacement = StoredValue::ReplaceIdentifier.call(
        identifier: @identifier,
        actor: current_user,
        identifier_type: params[:identifier_type].presence || "generated",
        raw_value: params[:raw_value]
      )
      flash_generated_identifier!(replacement) if params[:identifier_type].blank? || params[:identifier_type] == "generated"
      redirect_to customers_stored_value_account_path(@account), notice: "Identifier replaced."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def deactivate
      StoredValue::DeactivateIdentifier.call(identifier: @identifier, actor: current_user)
      redirect_to customers_stored_value_account_path(@account), notice: "Identifier deactivated."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    private

    def set_account
      @account = StoredValueAccount.find(params[:stored_value_account_id])
    end

    def set_identifier
      @identifier = @account.stored_value_identifiers.find(params[:id])
    end

    def flash_generated_identifier!(identifier)
      value = StoredValue::RevealIdentifier.call(identifier: identifier, actor: current_user, audit: false)
      store_revealed_identifier_flash!(identifier, value)
    end

    def store_revealed_identifier_flash!(identifier, value)
      flash[:stored_value_revealed_identifier] = {
        "id" => identifier.id,
        "value" => StoredValue::IdentifierCodec.format_display(value)
      }
    end
  end
end
