# frozen_string_literal: true

module Customers
  class StoredValueAccountOperationsController < BaseController
    before_action :set_account
    before_action -> { authorize!("stored_value.issue") }, only: :issue
    before_action -> { authorize!("stored_value.adjust") }, only: :adjust
    before_action -> { authorize!("stored_value.transfer") }, only: :transfer
    before_action -> { authorize!("stored_value.void") }, only: :void_entry

    def issue
      reason_code = StoredValueReasonCode.find(params[:reason_code_id])
      StoredValue::Issue.call(
        account: @account,
        store: customers_store,
        actor: current_user,
        amount_cents: params[:amount_cents].to_i,
        reason_code: reason_code,
        notes: params[:notes]
      )
      redirect_to customers_stored_value_account_path(@account), notice: "Credit issued."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def adjust
      reason_code = StoredValueReasonCode.find(params[:reason_code_id])
      StoredValue::Adjust.call(
        account: @account,
        store: customers_store,
        actor: current_user,
        amount_delta_cents: params[:amount_delta_cents].to_i,
        reason_code: reason_code,
        notes: params[:notes]
      )
      redirect_to customers_stored_value_account_path(@account), notice: "Balance adjusted."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def transfer
      to_account = StoredValueAccount.find(params[:to_account_id])
      reason_code = StoredValueReasonCode.find(params[:reason_code_id])
      StoredValue::Transfer.call(
        from_account: @account,
        to_account: to_account,
        store: customers_store,
        actor: current_user,
        amount_cents: params[:amount_cents].to_i,
        reason_code: reason_code,
        notes: params[:notes]
      )
      redirect_to customers_stored_value_account_path(@account), notice: "Balance transferred."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def void_entry
      entry = @account.stored_value_ledger_entries.find(params[:entry_id])
      reason_code = StoredValueReasonCode.find(params[:reason_code_id])
      StoredValue::VoidEntry.call(
        entry: entry,
        store: customers_store,
        actor: current_user,
        reason_code: reason_code,
        notes: params[:notes]
      )
      redirect_to customers_stored_value_account_path(@account), notice: "Ledger entry voided."
    rescue StandardError => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    private

    def set_account
      @account = StoredValueAccount.find(params[:stored_value_account_id])
    end
  end
end
