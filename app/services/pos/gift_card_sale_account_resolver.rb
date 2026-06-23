# frozen_string_literal: true

module Pos
  class GiftCardSaleAccountResolver
    Error = Class.new(StandardError)

    Result = Data.define(:account, :identifier)

    def self.resolve!(transaction:, actor:, stored_value_account_id: nil, stored_value_identifier_id: nil, lookup_code: nil, generate_identifier: false, reload: false)
      new(
        transaction:,
        actor:,
        stored_value_account_id:,
        stored_value_identifier_id:,
        lookup_code:,
        generate_identifier:,
        reload:
      ).resolve!
    end

    def initialize(transaction:, actor:, stored_value_account_id: nil, stored_value_identifier_id: nil, lookup_code: nil, generate_identifier: false, reload: false)
      @transaction = transaction
      @actor = actor
      @stored_value_account_id = stored_value_account_id
      @stored_value_identifier_id = stored_value_identifier_id
      @lookup_code = lookup_code
      @generate_identifier = generate_identifier
      @reload = reload
    end

    def self.resolve_for_sale!(transaction:, actor:, lookup_code:)
      new(transaction:, actor:, lookup_code:, generate_identifier: false).resolve_for_sale!
    end

    def resolve_for_sale!
      raise Error, "Card number is required." if lookup_code.blank?

      identifier = StoredValue::IdentifierCodec.lookup(lookup_code)
      if identifier.present?
        account = identifier.stored_value_account
        validate_account!(account)
        return Result.new(account:, identifier:)
      end

      account = nil
      identifier = nil
      ActiveRecord::Base.transaction do
        account = create_bearer_account!
        identifier = create_manual_identifier!(account)
      end
      Result.new(account:, identifier:)
    rescue StoredValue::IdentifierCodec::InvalidIdentifierError => e
      raise Error, friendly_identifier_error(e)
    rescue StoredValue::CreateIdentifier::Error => e
      raise Error, e.message
    end

    def resolve!
      if lookup_code.present?
        resolve_from_lookup!
      elsif stored_value_identifier_id.present?
        resolve_from_identifier_id!
      elsif stored_value_account_id.present?
        resolve_from_account_id!
      elsif generate_identifier
        resolve_or_create_bearer_account!
      else
        raise Error, "Gift card account or identifier is required."
      end
    end

    private

    attr_reader :transaction, :actor, :stored_value_account_id, :stored_value_identifier_id, :lookup_code, :generate_identifier, :reload

    def resolve_from_lookup!
      identifier = StoredValue::IdentifierCodec.lookup(lookup_code)
      raise Error, "No active account found for that identifier." if identifier.blank?

      account = identifier.stored_value_account
      validate_account!(account)
      Result.new(account:, identifier:)
    end

    def resolve_from_identifier_id!
      identifier = StoredValueIdentifier.find(stored_value_identifier_id)
      account = identifier.stored_value_account
      validate_account!(account)
      Result.new(account:, identifier:)
    end

    def resolve_from_account_id!
      account = StoredValueAccount.find(stored_value_account_id)
      validate_account!(account)
      Result.new(account:, identifier: nil)
    end

    def resolve_or_create_bearer_account!
      account = create_bearer_account!
      Result.new(account:, identifier: nil)
    end

    def create_bearer_account!
      authorize_account_creation!

      StoredValueAccount.create!(
        issuing_store: transaction.store,
        account_type: "gift_card",
        active: true
      )
    end

    def create_manual_identifier!(account)
      StoredValue::CreateIdentifier.call(
        account: account,
        actor: actor,
        identifier_type: "manual",
        raw_value: lookup_code
      )
    end

    def friendly_identifier_error(error)
      case error.message
      when "Check digit is invalid"
        "Card number check digit is invalid. Gift card numbers are 16 digits with a valid check digit, or leave blank to auto-generate."
      when "Identifier has invalid length"
        "Card number must be 16 digits (or leave blank to auto-generate)."
      when "Identifier must be numeric"
        "Card number must contain digits only."
      else
        error.message
      end
    end

    def authorize_account_creation!
      return if Authorization.allowed?(user: actor, permission_key: "stored_value.accounts.create", store: transaction.store)
      return if GiftCardSalePolicy.issue_permitted?(actor:, store: transaction.store)

      raise Error, "You are not authorized to create gift card accounts at POS."
    end

    def validate_account!(account)
      unless StoredValueTenderSupport.account_compatible_with_tender?(account:, tender_type: "gift_card")
        raise Error, "Account type is not compatible with gift card sales."
      end

      raise Error, "Stored value account is not active." unless account.postable?
    end
  end
end
