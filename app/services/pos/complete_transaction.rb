# frozen_string_literal: true

module Pos
  class CompleteTransaction
    Error = Class.new(StandardError)

    def self.call!(transaction:, completed_by_user:, register_session:, confirmed_inactive: false, pos_authorization_id: nil)
      new(
        transaction:,
        completed_by_user:,
        register_session:,
        confirmed_inactive:,
        pos_authorization_id:
      ).call!
    end

    def initialize(transaction:, completed_by_user:, register_session:, confirmed_inactive: false, pos_authorization_id: nil)
      @transaction = transaction
      @completed_by_user = completed_by_user
      @register_session = register_session
      @confirmed_inactive = confirmed_inactive
      @pos_authorization_id = pos_authorization_id
    end

    def call!
      raise Error, "Transaction is not editable." unless transaction.editable?
      raise Error, "Register session must be open." unless register_session&.open?
      raise Error, "Transaction must have at least one line." if transaction.pos_transaction_lines.empty?
      raise Error, "Transaction must have at least one tender." if transaction.pos_tenders.empty?

      transaction.pos_transaction_lines.each { |line| ReturnQuantityValidator.call!(line) }
      SellabilityValidator.validate!(transaction, confirmed_inactive: confirmed_inactive)
      validate_authorizations!

      PosTransaction.transaction do
        transaction.assign_attributes(
          pos_register_session: register_session,
          business_date: register_session.business_date,
          user_session: Current.user_session
        )

        snapshot_lines!
        RecalculateTransaction.call!(transaction, business_date: register_session.business_date)
        transaction.transaction_type = DeriveTransactionType.call(transaction)
        TenderValidator.validate!(transaction, pos_authorization_id: pos_authorization_id)
        TransactionNumberAssigner.call!(transaction)

        transaction.status = "completed"
        transaction.completed_at = Time.current
        transaction.save!

        PostInventory.call(transaction:, posted_by_user: completed_by_user)

        PosReceipt.create!(
          pos_transaction: transaction,
          store: transaction.store,
          receipt_number: transaction.transaction_number,
          issued_at: transaction.completed_at
        )

        AuditEvents.record!(
          actor: completed_by_user,
          event_name: "pos.transaction.completed",
          auditable: transaction,
          details: {
            "transaction_number" => transaction.transaction_number,
            "transaction_type" => transaction.transaction_type,
            "total_cents" => transaction.total_cents
          }
        )

        transaction
      end
    end

    private

    attr_reader :transaction, :completed_by_user, :register_session, :confirmed_inactive, :pos_authorization_id

    def validate_authorizations!
      if transaction.discount_cents.to_i > AuthorizationRequest::TRANSACTION_DISCOUNT_LIMIT_CENTS
        require_authorization!(:discount_over_limit, "Transaction discount exceeds limit; supervisor authorization required.")
      end

      if transaction.pos_transaction_lines.any? { |line| line.return_line? && line.source_transaction_line_id.blank? }
        require_authorization!(:no_receipt_return, "No-receipt return requires supervisor authorization.")
      end
    end

    def require_authorization!(authorization_type, message)
      authorization = PosAuthorization.find_by(id: pos_authorization_id)
      return if AuthorizationRequest.valid_for?(
        authorization: authorization,
        authorization_type: authorization_type.to_s,
        pos_transaction: transaction
      )

      raise Error, message
    end

    def snapshot_lines!
      transaction.pos_transaction_lines.each do |line|
        next unless line.variant_line? && line.product_variant.present?

        variant = line.product_variant
        product = variant.product
        line.assign_attributes(
          product: product,
          product_sku_snapshot: product.sku,
          variant_sku_snapshot: variant.sku,
          product_name_snapshot: product.name,
          variant_name_snapshot: variant.name,
          inventory_behavior_snapshot: variant.inventory_behavior,
          sub_department: variant.sub_department
        )
        line.save!
      end
    end
  end
end
