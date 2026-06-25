# frozen_string_literal: true

class BackfillPhase852aNormalTaxSnapshots < ActiveRecord::Migration[8.1]
  class LegacyPosTransaction < ApplicationRecord
    self.table_name = "pos_transactions"
  end

  class LegacyPosTransactionLine < ApplicationRecord
    self.table_name = "pos_transaction_lines"
  end

  def up
    LegacyPosTransactionLine.find_each do |line|
      applied_source = if sourced_return_line?(line)
        "sourced_return"
      elsif line.tax_cents.to_i.positive?
        "normal"
      else
        "non_taxable"
      end

      line.update_columns(
        normal_tax_category_id: line.tax_category_id,
        normal_store_tax_rate_id: line.store_tax_rate_id,
        normal_tax_rate_bps: line.tax_rate_bps,
        normal_tax_cents: line.tax_cents.to_i,
        normal_tax_identifier_snapshot: line.tax_identifier_snapshot,
        normal_store_tax_rate_short_name_snapshot: line.store_tax_rate_short_name_snapshot,
        applied_tax_source: applied_source
      )
    end

    LegacyPosTransaction.find_each do |transaction|
      normal_total = LegacyPosTransactionLine.where(pos_transaction_id: transaction.id).sum do |line|
        signed_line_amount(line, line.normal_tax_cents.to_i)
      end
      transaction.update_columns(normal_tax_cents: normal_total)
    end
  end

  def down
    LegacyPosTransactionLine.update_all(
      normal_tax_category_id: nil,
      normal_store_tax_rate_id: nil,
      normal_tax_rate_bps: nil,
      normal_tax_cents: 0,
      normal_tax_identifier_snapshot: nil,
      normal_store_tax_rate_short_name_snapshot: nil,
      applied_tax_source: nil
    )
    LegacyPosTransaction.update_all(normal_tax_cents: 0)
  end

  private

  def sourced_return_line?(line)
    line.quantity.to_i.negative? && line.source_transaction_line_id.present?
  end

  def signed_line_amount(line, magnitude_cents)
    line.quantity.to_i.negative? ? -magnitude_cents : magnitude_cents
  end
end
