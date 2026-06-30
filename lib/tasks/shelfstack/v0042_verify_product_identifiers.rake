# frozen_string_literal: true

module Shelfstack
  module V0042Verify
    module_function

    def duplicate_active_values(families)
      ProductIdentifier.active_records
        .where(validation_family: families)
        .group(:normalized_identifier)
        .having("COUNT(*) > 1")
        .count
        .keys
    end

    def legacy_reference_count
      count = 0
      Dir.glob(Rails.root.join("app/**/*.rb")).each do |path|
        next if path.include?("v0042/backfill_product_identifiers")

        content = File.read(path)
        count += content.scan("CatalogItemIdentifier").size
        count += content.scan("CatalogIdentifierService").size
        count += content.scan("LegacyProductIdentifierBridge").size
      end
      count
    end
  end
end

namespace :shelfstack do
  namespace :v0042 do
    desc "Verify v0.04-2 product identifier backfill and cutover readiness"
    task verify_product_identifiers: :environment do
      puts "=== v0.04-2 Product Identifier Verification ==="
      puts "products total: #{Product.count}"
      puts "products with identifiers: #{Product.joins(:product_identifiers).distinct.count}"
      puts "products with active primary: #{Product.joins(:product_identifiers).merge(ProductIdentifier.primary_records).distinct.count}"
      puts "products without identifiers: #{Product.left_joins(:product_identifiers).where(product_identifiers: { id: nil }).count}"

      ProductIdentifier::VALIDATION_FAMILIES.each do |family|
        count = ProductIdentifier.active_records.where(validation_family: family).count
        puts "product_identifiers #{family}: #{count}"
      end

      gtin_dupes = Shelfstack::V0042Verify.duplicate_active_values(%w[gtin house])
      isbn_dupes = Shelfstack::V0042Verify.duplicate_active_values(%w[isbn])
      puts "duplicate active gtin/house: #{gtin_dupes.count}"
      puts "duplicate active isbn: #{isbn_dupes.count}"
      gtin_dupes.each { |row| puts "  GTIN conflict: #{row}" }
      isbn_dupes.each { |row| puts "  ISBN conflict: #{row}" }

      puts "legacy_local: #{ProductIdentifier.active_records.where(validation_family: 'freeform', freeform_scope: 'legacy_local').count}"
      puts "legacy_product_sku: #{ProductIdentifier.active_records.where(validation_family: 'freeform', freeform_scope: 'legacy_product_sku').count}"

      InternalEanSequence.order(:segment).each do |row|
        puts "internal_ean_sequences #{row.segment}/#{row.purpose}: #{row.last_sequence}"
      end

      puts "legacy app references (catalog_item_identifiers string): #{Shelfstack::V0042Verify.legacy_reference_count}"

      if gtin_dupes.any? || isbn_dupes.any?
        puts "FAIL: duplicate active GTIN/ISBN identifiers detected"
        exit 1
      end

      if Shelfstack::V0042Verify.legacy_reference_count.positive?
        puts "FAIL: legacy catalog identifier references remain in app/"
        exit 1
      end

      puts "PASS: verification complete"
    end
  end
end
