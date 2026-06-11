# frozen_string_literal: true

class AddMerchandiseClassToCategories < ActiveRecord::Migration[8.0]
  def change
    add_reference :categories, :merchandise_class, foreign_key: true
  end
end
