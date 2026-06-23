# frozen_string_literal: true

module Pos
  class CompletionReadiness
    STRUCTURAL_KEYS = %i[
      register_session
      lines
      discount_auth
      no_receipt_return
      cash_refund_auth
    ].freeze

    Check = Data.define(:key, :status, :message, :action_key, :action_label)

    Result = Data.define(:checks, :ready) do
      def ready?
        ready
      end

      def blocked?
        !ready
      end

      def blockers
        checks.select { |check| check.status == :block }
      end

      def warnings
        checks.select { |check| check.status == :warn }
      end

      def structural_blockers
        blockers.select { |check| STRUCTURAL_KEYS.include?(check.key) }
      end

      def structural_blocked?
        structural_blockers.any?
      end

      def tender_check
        checks.find { |check| check.key == :tenders }
      end

      def tender_ready?
        check = tender_check
        check.nil? || check.status == :ok
      end

      def complete_ready?
        !structural_blocked? && tender_ready?
      end
    end

    def self.check(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil, actor: nil)
      new(
        transaction:,
        register_session:,
        tender_inputs:,
        confirmed_inactive:,
        pos_authorization_id:,
        actor:
      ).call
    end

    def self.preview(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil, actor: nil)
      check(
        transaction:,
        register_session:,
        tender_inputs:,
        confirmed_inactive:,
        pos_authorization_id:,
        actor:
      )
    end

    def initialize(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil, actor: nil)
      @transaction = transaction
      @register_session = register_session
      @tender_inputs = tender_inputs
      @confirmed_inactive = confirmed_inactive
      @pos_authorization_id = pos_authorization_id
      @actor = actor
    end

    def call
      checks = [
        register_session_check,
        lines_check,
        inactive_check,
        reserved_stock_authorization_check,
        discount_authorization_check,
        no_receipt_return_authorization_check,
        tender_total_check,
        stored_value_tender_check,
        cash_refund_authorization_check
      ].compact

      Result.new(
        checks: checks,
        ready: checks.none? { |check| check.status == :block }
      )
    end

    private

    attr_reader :transaction, :register_session, :tender_inputs, :confirmed_inactive, :pos_authorization_id, :actor

    def register_session_check
      if register_session&.open?
        Check.new(key: :register_session, status: :ok, message: "Register open", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :register_session,
          status: :block,
          message: "No register session is open",
          action_key: :open_register,
          action_label: "Open register"
        )
      end
    end

    def lines_check
      count = transaction.pos_transaction_lines.count
      if count.positive?
        Check.new(key: :lines, status: :ok, message: "#{count} #{'line'.pluralize(count)}", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :lines,
          status: :block,
          message: "Add at least one line",
          action_key: :focus_scan,
          action_label: "Scan item"
        )
      end
    end

    def inactive_check
      warnings = SellabilityValidator.warnings_for(transaction)
      if warnings.empty?
        Check.new(key: :inactive, status: :ok, message: "All items active", action_key: nil, action_label: nil)
      elsif confirmed_inactive
        Check.new(key: :inactive, status: :ok, message: "Inactive items confirmed", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :inactive,
          status: :warn,
          message: "#{warnings.size} inactive #{'item'.pluralize(warnings.size)} needs confirmation",
          action_key: :confirm_inactive,
          action_label: "Confirm inactive sale"
        )
      end
    end

    def reserved_stock_authorization_check
      return unless reserved_stock_override_needed?

      if authorization_valid?(:sell_reserved_stock_override)
        Check.new(key: :reserved_stock_auth, status: :ok, message: "Reserved stock override authorized", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :reserved_stock_auth,
          status: :block,
          message: "Selling into reserved stock requires manager authorization",
          action_key: :supervisor_auth,
          action_label: "Authorize override"
        )
      end
    end

    def reserved_stock_override_needed?
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

    def discount_authorization_check
      return unless transaction.discount_cents.to_i > AuthorizationRequest::TRANSACTION_DISCOUNT_LIMIT_CENTS

      if authorization_valid?(:discount_over_limit)
        Check.new(key: :discount_auth, status: :ok, message: "Discount authorized", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :discount_auth,
          status: :block,
          message: "Discount exceeds limit; manager authorization required",
          action_key: :supervisor_auth,
          action_label: "Authorize discount"
        )
      end
    end

    def no_receipt_return_authorization_check
      return unless transaction.pos_transaction_lines.any? { |line| line.return_line? && line.source_transaction_line_id.blank? }

      if authorization_valid?(:no_receipt_return)
        Check.new(key: :no_receipt_return, status: :ok, message: "No-receipt return authorized", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :no_receipt_return,
          status: :block,
          message: "No-receipt return requires manager approval",
          action_key: :supervisor_auth,
          action_label: "Manager sign-in"
        )
      end
    end

    def tender_total_check
      total_cents = transaction.total_cents
      tender_total = effective_tender_total_cents

      if tender_total.nil?
        Check.new(
          key: :tenders,
          status: :block,
          message: "Enter tender amounts",
          action_key: :fill_cash,
          action_label: "Fill cash"
        )
      elsif tender_total == total_cents
        Check.new(key: :tenders, status: :ok, message: "Tendered in full", action_key: nil, action_label: nil)
      else
        shortfall = total_cents - tender_total
        if shortfall.positive?
          Check.new(
            key: :tenders,
            status: :block,
            message: "Tender total is short by #{format_money(shortfall)}",
            action_key: :fill_cash,
            action_label: "Fill remaining with cash"
          )
        else
          Check.new(
            key: :tenders,
            status: :block,
            message: "Tender total exceeds amount due by #{format_money(shortfall.abs)}",
            action_key: :fill_cash,
            action_label: "Adjust tender"
          )
        end
      end
    end

    def stored_value_tender_check
      return unless actor.present?

      parsed_rows = if tender_inputs.present?
        SettlementInputParser.parse(transaction:, raw_inputs: tender_inputs).reject(&:destroy)
      else
        transaction.pos_tenders.settlement_rows.map do |tender|
          SettlementInputParser::ParsedRow.new(
            id: tender.id.to_s,
            destroy: false,
            tender_type: tender.tender_type,
            amount_cents: tender.amount_cents,
            tendered_cents: tender.tendered_cents,
            card_brand: tender.card_brand,
            card_last_four: tender.card_last_four,
            card_authorization_code: tender.card_authorization_code,
            check_number: tender.check_number,
            notes: tender.notes,
            stored_value_account_id: tender.stored_value_account_id&.to_s,
            stored_value_identifier_id: tender.stored_value_identifier_id&.to_s,
            lookup_code: nil,
            generate_identifier: tender.generate_stored_value_identifier?
          )
        end
      end

      sv_rows = parsed_rows.select { |row| Pos::StoredValueTenderSupport.stored_value_tender?(row.tender_type) }
      return if sv_rows.empty?

      unless TenderTypePolicy.allowed_types(transaction, actor:, store: transaction.store).intersect?(sv_rows.map(&:tender_type))
        return Check.new(
          key: :stored_value,
          status: :block,
          message: "Stored value tender type is not enabled for your role",
          action_key: nil,
          action_label: nil
        )
      end

      sv_rows.each do |row|
        next if row.generate_identifier
        next if row.stored_value_account_id.present?
        next if row.lookup_code.present?
        next if transaction.customer_id.present?

        return Check.new(
          key: :stored_value,
          status: :block,
          message: "Link a stored value account or enter an identifier",
          action_key: :open_settlement,
          action_label: "Open settlement"
        )
      end

      Check.new(key: :stored_value, status: :ok, message: "Stored value tenders ready", action_key: nil, action_label: nil)
    end

    def cash_refund_authorization_check
      return unless transaction.total_cents.negative?

      cash_amount = effective_cash_tender_cents
      return if cash_amount.nil? || cash_amount >= 0

      refund_amount = cash_amount.abs
      return unless refund_amount > TenderValidator::CASH_REFUND_THRESHOLD_CENTS

      if authorization_valid?(:cash_refund_over_threshold)
        Check.new(key: :cash_refund_auth, status: :ok, message: "Cash refund authorized", action_key: nil, action_label: nil)
      else
        Check.new(
          key: :cash_refund_auth,
          status: :block,
          message: "Cash refund exceeds threshold; supervisor authorization required",
          action_key: :supervisor_auth,
          action_label: "Authorize cash refund"
        )
      end
    end

    def effective_tender_total_cents
      if tender_inputs.blank?
        return transaction.pos_tenders.settlement_rows.sum(&:amount_cents) if transaction.pos_tenders.settlement_rows.any?

        return nil if transaction.total_cents.nonzero?

        return 0
      end

      parsed = SettlementInputParser.parse(transaction:, raw_inputs: tender_inputs)
      return nil if parsed.reject(&:destroy).empty? && transaction.total_cents.nonzero?

      total_cents = transaction.total_cents
      active = parsed.reject(&:destroy)
      if total_cents.positive?
        SettlementSync.preview_sale_totals(transaction, active)
      elsif total_cents.negative?
        active.sum(&:amount_cents)
      else
        active.sum(&:amount_cents)
      end
    end

    def effective_cash_tender_cents
      if tender_inputs.present?
        parsed = SettlementInputParser.parse(transaction:, raw_inputs: tender_inputs)
        cash = parsed.reject(&:destroy).find { |row| row.tender_type == "cash" }
        return nil if cash.blank?

        if transaction.total_cents.negative?
          cash.amount_cents
        else
          non_cash_sum = parsed.reject(&:destroy).reject { |row| row.tender_type == "cash" }.sum do |row|
            Pos::StoredValueTenderSupport.capped_redeem_amount_cents(
              transaction:,
              tender_type: row.tender_type,
              amount_cents: row.amount_cents,
              stored_value_account_id: row.stored_value_account_id
            )
          end
          remaining = transaction.total_cents - non_cash_sum
          if remaining.positive?
            [ cash.tendered_cents || cash.amount_cents, remaining ].min
          else
            cash.tendered_cents || cash.amount_cents
          end
        end
      else
        transaction.pos_tenders.settlement_rows.find { |t| t.tender_type == "cash" }&.amount_cents
      end
    end

    def parse_tender_inputs
      SettlementInputParser.parse(transaction:, raw_inputs: tender_inputs).map do |row|
        { tender_type: row.tender_type, amount_cents: row.amount_cents }
      end
    end

    def normalize_refund_amount_cents(amount_cents)
      SettlementInputParser.normalize_refund_amount_cents(transaction, amount_cents)
    end

    def authorization_valid?(authorization_type)
      AuthorizationRequest.granted_for_transaction?(
        transaction: transaction,
        authorization_type: authorization_type,
        pos_authorization_id: pos_authorization_id
      )
    end

    def format_money(cents)
      format("$%.2f", cents / 100.0)
    end
  end
end
