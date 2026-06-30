# frozen_string_literal: true

class BackfillV0041ProductMetadataFromCatalogItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  METADATA_COLUMNS = %w[
    catalog_item_type title subtitle creators creator_details publisher publisher_details
    publication_date publication_status series_name series_enumeration series_data format_id
    edition_statement language_code description year bisac_subjects bisac_subject_data genres
    genre_data themes theme_data target_audiences target_audience_data access_restrictions
    access_restriction_data publication_frequency digital large_print page_count duration_minutes
    height width depth dimension_units weight weight_units store_category_id
  ].freeze

  def up
    say_with_time "Backfill product metadata from catalog items" do
      Product.reset_column_information
      CatalogItem.reset_column_information

      Product.where.not(catalog_item_id: nil).find_each do |product|
        catalog_item = CatalogItem.find_by(id: product.catalog_item_id)
        next if catalog_item.blank?

        attrs = catalog_item.attributes.slice(*METADATA_COLUMNS)
        attrs["title"] ||= catalog_item.title
        attrs["name"] = product.name.presence || catalog_item.title if product.name.blank?
        product.update_columns(attrs.merge(updated_at: Time.current))
      end
    end

    say_with_time "Backfill product cover images from catalog thumbnails" do
      Product.includes(catalog_item: { primary_thumbnail_attachment: :blob })
        .where.not(catalog_item_id: nil)
        .find_each do |product|
        next if product.cover_image.attached?

        thumbnail = product.catalog_item&.primary_thumbnail
        next unless thumbnail&.attached?

        product.cover_image.attach(thumbnail.blob)
      end
    end

    say_with_time "Backfill product categorizations from catalog items" do
      Product.where.not(catalog_item_id: nil).find_each do |product|
        Categorization.where(categorizable_type: "CatalogItem", categorizable_id: product.catalog_item_id).find_each do |cat|
          next if Categorization.exists?(
            categorizable_type: "Product",
            categorizable_id: product.id,
            category_node_id: cat.category_node_id
          )

          cat.update_columns(categorizable_type: "Product", categorizable_id: product.id, updated_at: Time.current)
        end
      end
    end

    say_with_time "Backfill external lookup local_product_id" do
      ExternalLookupResult.where.not(local_catalog_item_id: nil).where(local_product_id: nil).find_each do |result|
        product = Product.find_by(catalog_item_id: result.local_catalog_item_id)
        next if product.blank?

        result.update_columns(local_product_id: product.id, updated_at: Time.current)
      end
    end

    say_with_time "Backfill external catalog import product_id" do
      ExternalCatalogImport.where.not(catalog_item_id: nil).where(product_id: nil).find_each do |import|
        product = Product.find_by(catalog_item_id: import.catalog_item_id)
        next if product.blank?

        import.update_columns(product_id: product.id, updated_at: Time.current)
      end
    end
  end

  def down
    # no-op: reseed is authoritative recovery path
  end
end
