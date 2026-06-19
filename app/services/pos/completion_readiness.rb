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

    def self.check(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil)
      new(
        transaction:,
        register_session:,
        tender_inputs:,
        confirmed_inactive:,
        pos_authorization_id:
      ).call
    end

    def self.preview(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil)
      check(
        transaction:,
        register_session:,
        tender_inputs:,
        confirmed_inactive:,
        pos_authorization_id:
      )
    end

    def initialize(transaction:, register_session:, tender_inputs: nil, confirmed_inactive: false, pos_authorization_id: nil)
      @transaction = transaction
      @register_session = register_session
      @tender_inputs = tender_inputs
      @confirmed_inactive = confirmed_inactive
      @pos_authorization_id = pos_authorization_id
    end

    def call
      checks = [
        register_session_check,
        lines_check,
        inactive_check,
        discount_authorization_check,
        no_receipt_return_authorization_check,
        tender_total_check,
        cash_refund_authorization_check
      ].compact

      Result.new(
        checks: checks,
        ready: checks.none? { |check| check.status == :block }
      )
    end

    private

    attr_reader :transaction, :register_session, :tender_inputs, :confirmed_inactive, :pos_authorization_id

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

    def cash_refund_authorization_check
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
        return transaction.pos_tenders.sum(&:amount_cents) if transaction.pos_tenders.any?

        return nil if transaction.total_cents.nonzero?

        return 0
      end

      parsed = parse_tender_inputs
      return nil if parsed.empty? && transaction.total_cents.nonzero?

      total_cents = transaction.total_cents
      if total_cents.positive?
        preview_sale_tender_total(parsed, total_cents)
      elsif total_cents.negative?
        parsed.sum { |t| t[:amount_cents] }
      else
        parsed.sum { |t| t[:amount_cents] }
      end
    end

    def preview_sale_tender_total(parsed, total_cents)
      non_cash = parsed.reject { |t| t[:tender_type] == "cash" }
      cash = parsed.find { |t| t[:tender_type] == "cash" }
      non_cash_sum = non_cash.sum { |t| t[:amount_cents] }
      return nil if non_cash_sum > total_cents

      remaining = total_cents - non_cash_sum
      return total_cents if remaining.zero?
      return nil if cash.blank?
      return nil if cash[:amount_cents] < remaining

      total_cents
    end

    def effective_cash_tender_cents
      if tender_inputs.present?
        cash = parse_tender_inputs.find { |t| t[:tender_type] == "cash" }
        return nil if cash.blank?

        if transaction.total_cents.negative?
          cash[:amount_cents]
        else
          non_cash_sum = parse_tender_inputs.reject { |t| t[:tender_type] == "cash" }.sum { |t| t[:amount_cents] }
          remaining = transaction.total_cents - non_cash_sum
          remaining.positive? ? -remaining : cash[:amount_cents]
        end
      else
        transaction.pos_tenders.find { |t| t.tender_type == "cash" }&.amount_cents
      end
    end

    def parse_tender_inputs
      Array(tender_inputs).filter_map do |attrs|
        amount_cents = if attrs[:amount_dollars].present?
          (BigDecimal(attrs[:amount_dollars].to_s) * 100).round.to_i
        else
          attrs[:amount_cents].to_i
        end

        next if amount_cents.zero? && !zero_total_tender_input?(attrs, amount_cents)

        amount_cents = normalize_refund_amount_cents(amount_cents)

        {
          tender_type: attrs[:tender_type],
          amount_cents: amount_cents
        }
      end
    end

    def normalize_refund_amount_cents(amount_cents)
      return amount_cents unless transaction.total_cents.negative?
      return amount_cents if amount_cents.negative?

      -amount_cents.abs
    end

    def zero_total_tender_input?(attrs, amount_cents)
      transaction.total_cents.zero? &&
        amount_cents.zero? &&
        (attrs[:amount_dollars].present? || attrs.key?(:amount_cents))
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
