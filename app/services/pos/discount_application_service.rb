# frozen_string_literal: true

module Pos
  class DiscountApplicationService
    Error = Class.new(StandardError)

    def self.call!(transaction:, scope:, discount_reason:, discount_method:, actor:, line: nil,
                  entered_amount_cents: nil, entered_percent_bps: nil, target_price_cents: nil,
                  note: nil, pos_authorization: nil)
      new(
        transaction:,
        scope:,
        line:,
        discount_reason:,
        discount_method:,
        entered_amount_cents:,
        entered_percent_bps:,
        target_price_cents:,
        note:,
        actor:,
        pos_authorization:
      ).call!
    end

    def initialize(transaction:, scope:, discount_reason:, discount_method:, actor:, line: nil,
                   entered_amount_cents: nil, entered_percent_bps: nil, target_price_cents: nil,
                   note: nil, pos_authorization: nil)
      @transaction = transaction
      @scope = scope.to_s
      @line = line
      @discount_reason = discount_reason
      @discount_method = discount_method.to_s
      @entered_amount_cents = entered_amount_cents
      @entered_percent_bps = entered_percent_bps
      @target_price_cents = target_price_cents
      @note = note
      @actor = actor
      @pos_authorization = pos_authorization
    end

    def call!
      validate_editable!
      validate_reason!
      validate_line!
      validate_transaction_eligibility!
      validate_note!
      validate_authorization!

      application = nil
      transaction.transaction do
        application = PosDiscountApplication.create!(
          pos_transaction: transaction,
          pos_transaction_line: line_scope? ? line : nil,
          discount_reason: discount_reason,
          pos_authorization: pos_authorization,
          scope: scope,
          source: "manual",
          discount_method: discount_method,
          entered_amount_cents: entered_amount_cents,
          entered_percent_bps: entered_percent_bps,
          target_price_cents: target_price_cents,
          note: note,
          stack_order: next_stack_order,
          applied_by_user: actor,
          approved_by_user: pos_authorization&.granted_by_user,
          applied_at: Time.current
        )
        DiscountRecalculator.call!(transaction)
      end

      application.reload
    end

    private

    attr_reader :transaction, :scope, :line, :discount_reason, :discount_method,
                :entered_amount_cents, :entered_percent_bps, :target_price_cents,
                :note, :actor, :pos_authorization

    def line_scope?
      scope == "line"
    end

    def validate_editable!
      raise Error, "Transaction is not editable." unless transaction.editable?
    end

    def validate_reason!
      raise Error, "Discount reason is not active." unless discount_reason.active?
    end

    def validate_line!
      return unless line_scope?

      raise Error, "Line is required for line-scope discounts." if line.blank?
      raise Error, "Line does not belong to this transaction." if line.pos_transaction_id != transaction.id

      eligibility = DiscountEligibilityResolver.call(line)
      raise Error, eligibility.message if !eligibility.discountable
    end

    def validate_transaction_eligibility!
      return if line_scope?

      base_cents = DiscountInput.discountable_transaction_base_cents(transaction.reload)
      return if base_cents.positive?

      raise Error, "No eligible merchandise remains for a transaction discount."
    end

    def validate_note!
      return unless discount_reason.requires_note?
      raise Error, "A note is required for this discount reason." if note.blank?
    end

    def validate_authorization!
      return unless discount_reason.requires_authorization?

      if pos_authorization.blank? ||
         !AuthorizationRequest.granted_for_transaction?(
           transaction: transaction,
           authorization_type: "discount_reason_approval",
           pos_authorization_id: pos_authorization.id
         )
        raise Error, "Manager authorization is required for this discount reason. Select Authorize discount before applying."
      end
    end

    def next_stack_order
      transaction.pos_discount_applications.active_records.maximum(:stack_order).to_i + 1
    end
  end
end
