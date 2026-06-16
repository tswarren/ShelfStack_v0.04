# frozen_string_literal: true

class RenameSubDepartmentsToSubDepartments < ActiveRecord::Migration[8.0]
  def change
    rename_table :sub_departments, :sub_departments
    rename_column :sub_departments, :sub_department_key, :sub_department_key
    rename_column :categories, :sub_department_id, :sub_department_id
    rename_column :accounting_mappings, :sub_department_id, :sub_department_id

    add_column :sub_departments, :default_variation_type, :string, null: false, default: "standard"
    add_column :sub_departments, :default_inventory_behavior, :string, null: false, default: "standard_physical"
  end
end
