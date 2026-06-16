# frozen_string_literal: true

class AddDepartmentIdToSubDepartments < ActiveRecord::Migration[8.0]
  class MigrationSubDepartment < ApplicationRecord
    self.table_name = "sub_departments"
  end

  class MigrationCategory < ApplicationRecord
    self.table_name = "categories"
  end

  class MigrationDepartment < ApplicationRecord
    self.table_name = "departments"
  end

  DEPARTMENT_NUMBER_BY_KEY = {
    "general_trade_books" => "001",
    "periodicals" => "002",
    "sidelines" => "003",
    "used_books" => "004",
    "gift_cards" => "005",
    "cafe" => "006",
    "books_juvenile_young_adult" => "001"
  }.freeze

  def up
    add_reference :sub_departments, :department, foreign_key: true, null: true unless column_exists?(:sub_departments, :department_id)

    MigrationSubDepartment.where(department_id: nil).find_each do |sub_department|
      department_id = department_id_for(sub_department)
      sub_department.update_columns(department_id: department_id) if department_id.present?
    end

    orphans = MigrationSubDepartment.where(department_id: nil).pluck(:sub_department_key)
    if orphans.any?
      raise ActiveRecord::IrreversibleMigration,
            "Cannot set sub_departments.department_id NOT NULL; unresolved: #{orphans.join(', ')}"
    end

    change_column_null :sub_departments, :department_id, false
  end

  def down
    remove_reference :sub_departments, :department, foreign_key: true, if_exists: true
  end

  private

  def department_id_for(sub_department)
    from_category = MigrationCategory.where(sub_department_id: sub_department.id).pick(:department_id)
    return from_category if from_category.present?

    number = DEPARTMENT_NUMBER_BY_KEY[sub_department.sub_department_key]
    number ||= inferred_department_number(sub_department)
    return if number.blank?

    MigrationDepartment.find_by(department_number: number)&.id
  end

  def inferred_department_number(sub_department)
    key = sub_department.sub_department_key.to_s
    name = sub_department.name.to_s.downcase

    return "001" if key.include?("book") || name.include?("book")
    return "002" if key.include?("periodical") || name.include?("periodical")
    return "003" if key.include?("sideline") || name.include?("gift") || name.include?("game")
    return "004" if key.include?("used")
    return "005" if key.include?("gift_card") || name.include?("gift card")
    return "006" if key.include?("cafe") || name.include?("cafe") || name.include?("food")

    nil
  end
end
