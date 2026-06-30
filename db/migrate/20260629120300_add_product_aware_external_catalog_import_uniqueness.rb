# frozen_string_literal: true

class AddProductAwareExternalCatalogImportUniqueness < ActiveRecord::Migration[8.0]
  def change
    add_index :external_catalog_imports,
              %i[external_lookup_result_id product_id action_type],
              unique: true,
              name: "index_external_catalog_imports_on_result_product_action_applied",
              where: <<~SQL.squish
                status = 'applied'
                AND product_id IS NOT NULL
                AND action_type IN (
                  'create_catalog_item',
                  'link_existing_catalog_item',
                  'fill_blank_existing_catalog_item'
                )
              SQL
  end
end
