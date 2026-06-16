# frozen_string_literal: true

class ClassificationTargetRetireLegacy < ActiveRecord::Migration[8.0]
  class MigrationProductVariant < ActiveRecord::Base
    self.table_name = "product_variants"
  end

  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  def up
    backfill_sub_departments!
    change_column_null :product_variants, :sub_department_id, false
    remove_reference :product_variants, :category, foreign_key: true
  end

  def down
    add_reference :product_variants, :category, null: true, foreign_key: true
    change_column_null :product_variants, :sub_department_id, true
  end

  private

  def backfill_sub_departments!
    MigrationProductVariant.where(sub_department_id: nil).find_each do |variant|
      category = MigrationCategory.find_by(id: variant.category_id)
      next if category.blank? || category.sub_department_id.blank?

      variant.update_columns(sub_department_id: category.sub_department_id)
    end

    remaining = MigrationProductVariant.where(sub_department_id: nil).count
    return if remaining.zero?

    raise "Cannot enforce sub_department_id NOT NULL: #{remaining} variant(s) still missing sub_department_id"
  end
end
