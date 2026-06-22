# frozen_string_literal: true

class ExtendPosTendersForSettlement < ActiveRecord::Migration[8.0]
  TENDERED_PREFIX = "tendered_cents:"

  def up
    add_column :pos_tenders, :line_number, :integer
    add_column :pos_tenders, :tendered_cents, :integer
    add_column :pos_tenders, :change_cents, :integer
    add_column :pos_tenders, :card_brand, :string
    add_column :pos_tenders, :card_last_four, :string
    add_column :pos_tenders, :card_authorization_code, :string
    add_column :pos_tenders, :check_number, :string
    add_column :pos_tenders, :notes, :text

    backfill_line_numbers
    backfill_cash_tendered
    backfill_card_brands

    change_column_null :pos_tenders, :line_number, false
    add_index :pos_tenders, %i[pos_transaction_id line_number], unique: true
  end

  def down
    remove_index :pos_tenders, column: %i[pos_transaction_id line_number]
    remove_column :pos_tenders, :notes
    remove_column :pos_tenders, :check_number
    remove_column :pos_tenders, :card_authorization_code
    remove_column :pos_tenders, :card_last_four
    remove_column :pos_tenders, :card_brand
    remove_column :pos_tenders, :change_cents
    remove_column :pos_tenders, :tendered_cents
    remove_column :pos_tenders, :line_number
  end

  private

  def backfill_line_numbers
    execute <<~SQL.squish
      UPDATE pos_tenders AS pt
      SET line_number = numbered.row_number
      FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY pos_transaction_id ORDER BY id) AS row_number
        FROM pos_tenders
      ) AS numbered
      WHERE pt.id = numbered.id
    SQL
  end

  def backfill_cash_tendered
    PosTender.reset_column_information
    PosTender.where(tender_type: "cash").find_each do |tender|
      reference = tender.reference_number.to_s
      next unless reference.start_with?(TENDERED_PREFIX)

      tendered = reference.delete_prefix(TENDERED_PREFIX).to_i
      change = [ tendered - tender.amount_cents, 0 ].max
      tender.update_columns(
        tendered_cents: tendered,
        change_cents: change.positive? ? change : nil,
        reference_number: nil
      )
    end
  end

  def backfill_card_brands
    execute <<~SQL.squish
      UPDATE pos_tenders
      SET card_brand = 'other'
      WHERE tender_type = 'card' AND (card_brand IS NULL OR card_brand = '')
    SQL
  end
end
