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
      if transaction.pos_tenders.empty? && !transaction.total_cents.zero?
        raise Error, "Transaction must have at least one tender."
      end

      transaction.pos_transaction_lines.each { |line| ReturnQuantityValidator.call!(line) }
      SellabilityValidator.validate!(transaction, confirmed_inactive: confirmed_inactive, pos_authorization_id: pos_authorization_id)
      validate_authorizations!
      validate_gift_card_sales!

      PosTransaction.transaction do
        transaction.assign_attributes(
          pos_register_session: register_session,
          business_date: register_session.business_date,
          user_session: Current.user_session
        )

        snapshot_lines!
        snapshot_cogs!
        RecalculateTransaction.call!(transaction, business_date: register_session.business_date)
        transaction.transaction_type = DeriveTransactionType.call(transaction)
        TenderValidator.validate!(transaction, actor: completed_by_user, pos_authorization_id: pos_authorization_id)
        stored_value_result = PostStoredValueLedger.call!(
          transaction:,
          actor: completed_by_user,
          store: transaction.store
        )
        gift_card_result = PostGiftCardSaleLedger.call!(
          transaction:,
          actor: completed_by_user,
          store: transaction.store
        )
        transaction.pos_generated_stored_value_identifiers =
          stored_value_result.generated_identifiers + gift_card_result.generated_identifiers
        TransactionNumberAssigner.call!(transaction)

        transaction.status = "completed"
        transaction.completed_at = Time.current
        transaction.save!

        PostInventory.call(transaction:, posted_by_user: completed_by_user)
        CompleteReservationFulfillment.call!(transaction:, fulfilled_by_user: completed_by_user)

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

      if reserved_stock_override_required?
        require_authorization!(:sell_reserved_stock_override, "Selling reserved stock requires manager override.")
      end
    end

    def reserved_stock_override_required?
      transaction.pos_transaction_lines.any? do |line|
        next false unless line.variant_line?
        next false if line.product_variant.blank?
        next false if line.inventory_reservation_id.present?

        variant = line.product_variant
        reserved = Inventory::Availability.reserved(store: transaction.store, variant: variant)
        next false if reserved.zero?

        available = Inventory::Availability.available(store: transaction.store, variant: variant)
        line.quantity.abs > available
      end
    end

    def require_authorization!(authorization_type, message)
      return if AuthorizationRequest.granted_for_transaction?(
        transaction: transaction,
        authorization_type: authorization_type,
        pos_authorization_id: pos_authorization_id
      )

      raise Error, message
    end

    def snapshot_lines!
      transaction.pos_transaction_lines.each do |line|
        if line.variant_line? && line.product_variant.present?
          snapshot_variant_line!(line)
        elsif line.open_ring_line?
          snapshot_open_ring_line!(line)
        elsif line.gift_card_sale_line?
          snapshot_gift_card_sale_line!(line)
        end
      end
    end

    def snapshot_variant_line!(line)
      variant = line.product_variant
      product = variant.product
      line.assign_attributes(
        product: product,
        product_sku_snapshot: product.sku,
        variant_sku_snapshot: variant.sku,
        product_name_snapshot: product.name,
        variant_name_snapshot: variant.name,
        inventory_behavior_snapshot: variant.inventory_behavior,
        inventory_tracking_snapshot: Inventory::TrackingResolver.resolve(variant),
        sub_department: variant.sub_department,
        sub_department_name_snapshot: variant.sub_department&.name
      )
      line.save!
    end

    def snapshot_open_ring_line!(line)
      line.assign_attributes(
        sub_department_name_snapshot: line.sub_department&.name
      )
      line.save!
    end

    def snapshot_gift_card_sale_line!(line)
      line.assign_attributes(
        sub_department_name_snapshot: line.sub_department&.name,
        open_ring_description: line.open_ring_description.presence || PosTransactionLine::GIFT_CARD_SALE_DESCRIPTION,
        inventory_behavior_snapshot: "pure_financial",
        inventory_tracking_snapshot: Inventory::TrackingResolver::NON_INVENTORY_TRACKING
      )
      line.save!
    end

    def snapshot_cogs!
      transaction.pos_transaction_lines.each { |line| assign_cogs_snapshot!(line) && line.save! }
    end

    def assign_cogs_snapshot!(line)
      result = LineCogsCalculator.call(line: line, store: transaction.store)
      line.assign_attributes(
        unit_cogs_cents: result.unit_cogs_cents,
        total_cogs_cents: result.total_cogs_cents,
        cogs_source: result.cogs_source,
        costing_method_snapshot: result.costing_method_snapshot,
        revenue_treatment: result.revenue_treatment,
        cogs_estimated: result.cogs_estimated
      )
      true
    end

    def validate_gift_card_sales!
      transaction.pos_transaction_lines.select(&:gift_card_sale_line?).each do |line|
        next if GiftCardSaleSupport.activation_ready?(line)

        raise Error, "Gift card sale lines require a card number or auto-generation."
      end
    end
  end
end
