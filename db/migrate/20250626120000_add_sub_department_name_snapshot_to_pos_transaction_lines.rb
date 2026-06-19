# frozen_string_literal: true

class AddSubDepartmentNameSnapshotToPosTransactionLines < ActiveRecord::Migration[8.0]
  def change
    add_column :pos_transaction_lines, :sub_department_name_snapshot, :string
  end
end
