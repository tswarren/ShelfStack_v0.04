# frozen_string_literal: true

class CreatePhase7aCustomerContactEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_contact_events do |t|
      t.references :customer, foreign_key: true
      t.references :customer_request, foreign_key: true
      t.references :customer_request_line, foreign_key: true
      t.string :contact_method, null: false
      t.string :direction, null: false
      t.string :status, null: false
      t.text :summary, null: false
      t.references :recorded_by_user, null: false, foreign_key: { to_table: :users }
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :customer_contact_events, :occurred_at
  end
end
