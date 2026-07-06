# frozen_string_literal: true

class AddAppearancePreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :appearance_view_mode, :string, null: false, default: "standard"
    add_column :users, :appearance_color_mode, :string, null: false, default: "light"
  end
end
