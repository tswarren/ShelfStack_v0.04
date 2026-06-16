# frozen_string_literal: true

class CreateCategorySchemesAndNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :category_schemes do |t|
      t.string :scheme_key, null: false
      t.string :name, null: false
      t.string :purpose, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :category_schemes, :scheme_key, unique: true
    add_index :category_schemes, :name, unique: true

    create_table :category_nodes do |t|
      t.references :category_scheme, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :category_nodes }
      t.string :node_key, null: false
      t.string :name, null: false
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :category_nodes, %i[category_scheme_id node_key], unique: true
    add_index :category_nodes, %i[category_scheme_id name], unique: true

    create_table :categorizations do |t|
      t.references :category_node, null: false, foreign_key: true
      t.references :categorizable, polymorphic: true, null: false
      t.boolean :primary, null: false, default: false
      t.string :source
      t.timestamps
    end

    add_index :categorizations, %i[categorizable_type categorizable_id category_node_id],
              unique: true, name: "index_categorizations_on_categorizable_and_node"
  end
end
