# frozen_string_literal: true

module Pos
  class DiscountRecalculator
    def self.call!(transaction)
      new(transaction).call!
    end

    def initialize(transaction)
      @transaction = transaction.reload
    end

    def call!
      transaction.pos_discount_allocations.delete_all
      reset_line_discount_caches!

      active_applications.each do |application|
        apply_application!(application)
      end

      transaction.discount_cents = transaction.pos_transaction_lines.sum(&:transaction_discount_cents)
      transaction.save!
      transaction
    end

    private

    attr_reader :transaction

    def active_applications
      transaction.pos_discount_applications.active_records.order(:stack_order, :created_at, :id)
    end

    def reset_line_discount_caches!
      transaction.pos_transaction_lines.each do |line|
        next if sourced_return_line?(line)

        base = line_base_cents(line)
        line.update!(
          line_discount_cents: 0,
          transaction_discount_cents: 0,
          extended_price_cents: base
        )
      end
    end

    def apply_application!(application)
      case application.scope
      when "line"
        apply_line_application!(application)
      when "transaction"
        transaction.pos_transaction_lines.reset
        apply_transaction_application!(application)
      end
    end

    def apply_line_application!(application)
      line = application.pos_transaction_line
      return if line.blank?
      return if sourced_return_line?(line)

      line.reload

      remaining = remaining_line_amount(line)
      return if remaining.zero?

      eligibility = DiscountEligibilityResolver.call(line, remaining_discountable_cents: remaining)
      unless eligibility.discountable
        update_application_totals!(application, remaining, 0)
        return
      end

      discount = calculate_discount(application, remaining)
      return if discount.zero?

      create_allocation!(application, line, remaining, discount)
      line.line_discount_cents += discount
      line.extended_price_cents = [ line_base_cents(line) - line.line_discount_cents - line.transaction_discount_cents, 0 ].max
      line.save!

      update_application_totals!(application, remaining, discount)
    end

    def apply_transaction_application!(application)
      eligible_lines = eligible_transaction_lines
      base_total = eligible_lines.sum { |line| remaining_line_amount(line) }
      return if base_total.zero?

      discount = calculate_discount(application, base_total)
      return if discount.zero?

      allocate_transaction_discount_shares(eligible_lines, discount, base_total).each do |entry|
        line = entry[:line]
        share = entry[:share]
        line_remaining = entry[:line_remaining]
        next if share.zero?

        line.reload
        create_allocation!(application, line, line_remaining, share)
        line.transaction_discount_cents += share
        line.extended_price_cents = [ line_base_cents(line) - line.line_discount_cents - line.transaction_discount_cents, 0 ].max
        line.save!
      end

      update_application_totals!(application, base_total, discount)
    end

    def allocate_transaction_discount_shares(eligible_lines, discount, base_total)
      weighted = eligible_lines.filter_map do |line|
        line_remaining = remaining_line_amount(line)
        next if line_remaining.zero?

        exact = Rational(discount * line_remaining, base_total)
        {
          line: line,
          line_remaining: line_remaining,
          floor: exact.floor.to_i,
          fraction: exact - exact.floor
        }
      end

      remainder = discount - weighted.sum { |entry| entry[:floor] }
      if remainder.positive?
        weighted.sort_by { |entry| [ -entry[:fraction], entry[:line].line_number, entry[:line].id ] }
                .first(remainder)
                .each { |entry| entry[:floor] += 1 }
      end

      weighted.filter_map do |entry|
        share = [ entry[:floor], entry[:line_remaining] ].min
        next if share.zero?

        { line: entry[:line], line_remaining: entry[:line_remaining], share: share }
      end
    end

    def calculate_discount(application, base_cents)
      case application.discount_method
      when "amount"
        [ application.entered_amount_cents.to_i, base_cents ].min
      when "percent"
        raw = ((base_cents * application.entered_percent_bps.to_i) / 10_000.0).round
        [ raw, base_cents ].min
      when "price_override"
        [ base_cents - application.target_price_cents.to_i, 0 ].max.clamp(0, base_cents)
      else
        0
      end
    end

    def eligible_transaction_lines
      transaction.pos_transaction_lines.select do |line|
        next false if sourced_return_line?(line)
        next false unless line.quantity.positive?

        remaining = remaining_line_amount(line)
        next false if remaining.zero?

        DiscountEligibilityResolver.call(line, remaining_discountable_cents: remaining).discountable
      end
    end

    def sourced_return_line?(line)
      line.return_line? && line.source_transaction_line_id.present?
    end

    def remaining_line_amount(line)
      [ line_base_cents(line) - line.line_discount_cents.to_i - line.transaction_discount_cents.to_i, 0 ].max
    end

    def line_base_cents(line)
      line.unit_price_cents.to_i * line.quantity.abs
    end

    def create_allocation!(application, line, allocation_base_cents, allocated_discount_cents)
      snapshots = allocation_snapshots(line)
      PosDiscountAllocation.create!(
        pos_discount_application: application,
        pos_transaction: transaction,
        pos_transaction_line: line,
        scope: application.scope,
        allocation_base_cents: allocation_base_cents,
        allocated_discount_cents: allocated_discount_cents,
        **snapshots
      )
    end

    def allocation_snapshots(line)
      variant = line.product_variant
      product = line.product || variant&.product
      sub_department = line.sub_department || variant&.sub_department
      department = sub_department&.department

      {
        line_number_snapshot: line.line_number,
        product_variant_id: variant&.id,
        product_id: product&.id,
        sub_department_id: sub_department&.id,
        department_id: department&.id,
        tax_category_id: line.tax_category_id,
        variant_sku_snapshot: line.variant_sku_snapshot.presence || variant&.sku,
        variant_name_snapshot: line.variant_name_snapshot.presence || variant&.name,
        product_name_snapshot: line.product_name_snapshot.presence || product&.name,
        sub_department_name_snapshot: line.sub_department_name_snapshot.presence || sub_department&.name,
        department_name_snapshot: department&.name
      }
    end

    def update_application_totals!(application, base_amount_cents, applied_discount_cents)
      application.update!(
        base_amount_cents: base_amount_cents,
        calculated_discount_cents: applied_discount_cents,
        applied_discount_cents: applied_discount_cents
      )
    end
  end
end
