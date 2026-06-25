# frozen_string_literal: true

class AddLockedReturnPathToUserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_sessions, :locked_return_path, :string, limit: 2048
  end
end
