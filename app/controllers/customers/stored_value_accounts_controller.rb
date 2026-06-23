# frozen_string_literal: true

module Customers
  class StoredValueAccountsController < BaseController
    before_action :set_account, only: %i[show edit update suspend close reactivate]
    before_action -> { authorize!("stored_value.accounts.view") }, only: %i[index show lookup]
    before_action -> { authorize!("stored_value.accounts.create") }, only: %i[new create]
    before_action -> { authorize!("stored_value.accounts.update") }, only: %i[edit update]
    before_action -> { authorize!("stored_value.accounts.suspend") }, only: :suspend
    before_action -> { authorize!("stored_value.accounts.close") }, only: :close
    before_action -> { authorize!("stored_value.accounts.reactivate") }, only: :reactivate

    def index
      @accounts = StoredValueAccount.includes(:issuing_store, :customer).order(created_at: :desc)
      @accounts = @accounts.where(issuing_store: customers_store) if params[:store_scope] != "all"
      @accounts = @accounts.where(account_type: params[:account_type]) if params[:account_type].present?
      @accounts = @accounts.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    end

    def show
      @identifiers = @account.stored_value_identifiers.order(created_at: :desc)
      @ledger_entries = @account.stored_value_ledger_entries.includes(:store, :reason_code, :created_by_user).posted_order.limit(50)
      @audit_events = AuditEvent.for_auditable(@account).limit(20)
      @reason_codes = StoredValueReasonCode.active_records.order(:name)
    end

    def lookup
      if params[:code].present?
        @identifier = StoredValue::IdentifierCodec.lookup(params[:code])
        if @identifier
          redirect_to customers_stored_value_account_path(@identifier.stored_value_account)
          return
        end
        flash.now[:alert] = "No active account found for that identifier."
      end

      index
      render :index, status: (params[:code].present? ? :not_found : :ok)
    end

    def new
      @account = StoredValueAccount.new(
        issuing_store: customers_store,
        active: true,
        customer_id: params[:customer_id]
      )
      @customers = Customer.active_records.order(:display_name)
      @stores = Store.active_records.order(:store_number)
    end

    def create
      @account = StoredValueAccount.new(account_params)
      if @account.save
        record_audit!("stored_value.account.created", @account)
        redirect_to customers_stored_value_account_path(@account), notice: "Stored value account created."
      else
        @customers = Customer.active_records.order(:display_name)
        @stores = Store.active_records.order(:store_number)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @customers = Customer.active_records.order(:display_name)
      @stores = Store.active_records.order(:store_number)
    end

    def update
      if @account.update(account_params)
        record_audit!("stored_value.account.updated", @account)
        redirect_to customers_stored_value_account_path(@account), notice: "Stored value account updated."
      else
        @customers = Customer.active_records.order(:display_name)
        @stores = Store.active_records.order(:store_number)
        render :edit, status: :unprocessable_entity
      end
    end

    def suspend
      @account.suspend!
      record_audit!("stored_value.account.suspended", @account)
      redirect_to customers_stored_value_account_path(@account), notice: "Account suspended."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def close
      @account.close!
      record_audit!("stored_value.account.closed", @account)
      redirect_to customers_stored_value_account_path(@account), notice: "Account closed."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to customers_stored_value_account_path(@account), alert: e.message
    end

    def reactivate
      @account.reactivate!
      record_audit!("stored_value.account.reactivated", @account)
      redirect_to customers_stored_value_account_path(@account), notice: "Account reactivated."
    end

    private

    def set_account
      @account = StoredValueAccount.find(params[:id])
    end

    def account_params
      params.require(:stored_value_account).permit(
        :issuing_store_id, :customer_id, :account_type, :holder_name_snapshot, :notes
      )
    end
  end
end
