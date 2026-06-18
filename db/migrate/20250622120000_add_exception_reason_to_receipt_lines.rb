# frozen_string_literal: true

class AddExceptionReasonToReceiptLines < ActiveRecord::Migration[8.0]
  def change
    add_column :receipt_lines, :exception_reason, :string
  end
end
