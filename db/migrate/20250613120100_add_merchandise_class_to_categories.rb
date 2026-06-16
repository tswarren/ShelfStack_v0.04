# frozen_string_literal: true

class AddSubDepartmentToCategories < ActiveRecord::Migration[8.0]
  def change
    add_reference :categories, :sub_department, foreign_key: true
  end
end
