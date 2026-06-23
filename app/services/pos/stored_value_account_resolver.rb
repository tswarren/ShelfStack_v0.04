# frozen_string_literal: true

module Pos
  class StoredValueAccountResolver
    Error = Class.new(StandardError)

    Result = Data.define(:account, :identifier)

    def self.resolve!(transaction:, tender_type:, actor:, stored_value_account_id: nil, lookup_code: nil, generate_identifier: false)
      new(
        transaction:,
        tender_type:,
        actor:,
        stored_value_account_id:,
        lookup_code:,
        generate_identifier:
      ).resolve!
    end

    def initialize(transaction:, tender_type:, actor:, stored_value_account_id: nil, lookup_code: nil, generate_identifier: false)
      @transaction = transaction
      @tender_type = tender_type
      @actor = actor
      @stored_value_account_id = stored_value_account_id
      @lookup_code = lookup_code
      @generate_identifier = generate_identifier
    end

    def resolve!
      if lookup_code.present?
        resolve_from_lookup!
      elsif stored_value_account_id.present?
        resolve_from_account_id!
      elsif transaction.customer_id.present?
        resolve_or_create_customer_account!
      elsif generate_identifier && issue_refund?
        resolve_or_create_bearer_account!
      else
        raise Error, "Stored value account is required."
      end
    end

    private

    attr_reader :transaction, :tender_type, :actor, :stored_value_account_id, :lookup_code, :generate_identifier

    def issue_refund?
      TenderTypePolicy.refund_transaction?(transaction) && tender_type == "store_credit"
    end

    def resolve_from_lookup!
      identifier = StoredValue::IdentifierCodec.lookup(lookup_code)
      raise Error, "No active account found for that identifier." if identifier.blank?

      account = identifier.stored_value_account
      validate_account!(account)
      Result.new(account:, identifier:)
    end

    def resolve_from_account_id!
      account = StoredValueAccount.find(stored_value_account_id)
      validate_account!(account)
      Result.new(account:, identifier: nil)
    end

    def resolve_or_create_customer_account!
      account_type = StoredValueTenderSupport.default_account_type_for_tender(tender_type)
      account = StoredValueAccount.active_records.find_by(
        customer_id: transaction.customer_id,
        issuing_store_id: transaction.store_id,
        account_type: account_type
      )

      account ||= create_customer_account!(account_type)
      validate_account!(account)
      Result.new(account:, identifier: nil)
    end

    def resolve_or_create_bearer_account!
      account_type = StoredValueTenderSupport.default_account_type_for_tender(tender_type)
      account = create_bearer_account!(account_type)
      validate_account!(account)
      Result.new(account:, identifier: nil)
    end

    def create_customer_account!(account_type)
      authorize_account_creation!
      authorize_refund_issue!

      customer = Customer.find(transaction.customer_id)
      StoredValueAccount.create!(
        issuing_store: transaction.store,
        customer: customer,
        account_type: account_type,
        holder_name_snapshot: customer.display_name,
        active: true
      )
    end

    def create_bearer_account!(account_type)
      authorize_account_creation!
      authorize_refund_issue!

      StoredValueAccount.create!(
        issuing_store: transaction.store,
        account_type: account_type,
        active: true
      )
    end

    def authorize_account_creation!
      return if Authorization.allowed?(user: actor, permission_key: "stored_value.accounts.create", store: transaction.store)
      return if TenderTypePolicy.refund_store_credit_permitted?(actor:, store: transaction.store)

      raise Error, "You are not authorized to create stored value accounts at POS."
    end

    def authorize_refund_issue!
      return if TenderTypePolicy.refund_store_credit_permitted?(actor:, store: transaction.store)

      raise Error, "You are not authorized to issue store credit from POS."
    end

    def validate_account!(account)
      unless StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type:)
        raise Error, "Account type is not compatible with #{tender_type} tender."
      end

      raise Error, "Stored value account is not active." unless account.postable?
    end
  end
end
