# frozen_string_literal: true

module Pos
  class ReadinessPreviewResponse
    def self.build(readiness:, transaction:, confirm_inactive: false, tender_inputs: nil)
      new(readiness:, transaction:, confirm_inactive:, tender_inputs:).build
    end

    def initialize(readiness:, transaction:, confirm_inactive: false, tender_inputs: nil)
      @readiness = readiness
      @transaction = transaction
      @confirm_inactive = confirm_inactive
      @tender_inputs = tender_inputs
    end

    def build
      change_cents, remaining_cents = tender_amounts

      {
        checks: readiness.checks.map { |check| serialize_check(check) },
        structural_blocked: readiness.structural_blocked?,
        tender_ready: readiness.tender_ready?,
        complete_ready: readiness.complete_ready?,
        complete_label: complete_label(change_cents, remaining_cents),
        change_cents: change_cents,
        remaining_cents: remaining_cents
      }
    end

    private

    attr_reader :readiness, :transaction, :confirm_inactive, :tender_inputs

    def serialize_check(check)
      payload = {
        key: check.key,
        status: check.status,
        message: check.message,
        action_key: check.action_key,
        action_label: check.action_label
      }

      if check.action_key == :supervisor_auth
        payload[:authorization_type] = authorization_type_for(check.key)
      end

      payload
    end

    def authorization_type_for(key)
      case key
      when :discount_auth then "discount_over_limit"
      when :discount_reason_auth then "discount_reason_approval"
      when :no_receipt_return then "no_receipt_return"
      when :cash_refund_auth then "cash_refund_over_threshold"
      when :reserved_stock_auth then "sell_reserved_stock_override"
      end
    end

    def complete_label(change_cents, remaining_cents)
      ApplicationController.helpers.pos_complete_button_label(
        transaction,
        confirm_inactive: confirm_inactive,
        change_cents: change_cents,
        remaining_cents: remaining_cents
      )
    end

    def tender_amounts
      total = transaction.total_cents
      parsed = SettlementInputParser.parse(transaction:, raw_inputs: tender_inputs).reject(&:destroy)

      if total.positive?
        non_cash = parsed.reject { |row| row.tender_type == "cash" }
        cash = parsed.find { |row| row.tender_type == "cash" }
        non_cash_sum = non_cash.sum(&:amount_cents)
        remaining = total - non_cash_sum
        cash_tendered = cash&.tendered_cents || cash&.amount_cents.to_i
        change = cash_tendered.positive? ? [ cash_tendered - remaining, 0 ].max : 0
        still_due = remaining.positive? ? [ remaining - cash_tendered, 0 ].max : 0
        [ change, still_due ]
      elsif total.negative?
        tender_total = parsed.sum(&:amount_cents)
        still_due = (total - tender_total).abs
        [ 0, still_due ]
      else
        [ 0, 0 ]
      end
    end
  end
end
