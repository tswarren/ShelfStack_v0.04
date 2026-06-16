# frozen_string_literal: true

class ScopeCategoryNodeNameUniquenessToParent < ActiveRecord::Migration[8.0]
  def change
    remove_index :category_nodes, column: %i[category_scheme_id name], if_exists: true
    add_index :category_nodes, %i[category_scheme_id name],
              unique: true,
              where: "parent_id IS NULL",
              name: "index_category_nodes_on_scheme_and_root_name"
    add_index :category_nodes, %i[category_scheme_id parent_id name],
              unique: true,
              where: "parent_id IS NOT NULL",
              name: "index_category_nodes_on_scheme_parent_and_name"
  end
end
