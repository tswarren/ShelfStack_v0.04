# frozen_string_literal: true

class AddEncryptedValueToStoredValueIdentifiers < ActiveRecord::Migration[8.0]
  def change
    add_column :stored_value_identifiers, :encrypted_value, :text
  end
end
