# frozen_string_literal: true

class RelaxSubDepartmentShortNameUniqueness < ActiveRecord::Migration[8.0]
  def change
    remove_index :sub_departments, :short_name, unique: true
    add_index :sub_departments, :short_name
  end
end
