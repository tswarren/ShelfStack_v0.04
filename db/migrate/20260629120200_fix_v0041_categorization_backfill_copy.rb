# frozen_string_literal: true

class FixV0041CategorizationBackfillCopy < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    say_with_time "Restore catalog categorizations and copy to all linked products" do
      Product.reset_column_information
      CatalogItem.reset_column_information

      Product.where.not(catalog_item_id: nil).find_each do |product|
        catalog_item = CatalogItem.find_by(id: product.catalog_item_id)
        next if catalog_item.blank?

        Products::CopyCategorizationsFromCatalogItem.sync_product_and_catalog(product, catalog_item)
      end
    end
  end

  def down
    # no-op: reseed is authoritative recovery path
  end
end
