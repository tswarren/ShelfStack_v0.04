# frozen_string_literal: true

class AddCustomerSearchIndexes < ActiveRecord::Migration[8.0]
  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :customers, :display_name, using: :gin, opclass: :gin_trgm_ops,
              name: "index_customers_on_display_name_trgm"
    add_index :customers, :email, using: :gin, opclass: :gin_trgm_ops,
              name: "index_customers_on_email_trgm"
    add_index :customers, :phone, using: :gin, opclass: :gin_trgm_ops,
              name: "index_customers_on_phone_trgm"
  end

  def down
    remove_index :customers, name: "index_customers_on_display_name_trgm"
    remove_index :customers, name: "index_customers_on_email_trgm"
    remove_index :customers, name: "index_customers_on_phone_trgm"
  end
end
