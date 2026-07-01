# frozen_string_literal: true

# v0.04-4 verification — allowlist categories from spec audit table:
#   Shim, Metadata admin, Defer, Preserve, Replace (in progress until merge gate)
#
# Merge gate (STRICT=1 or slice 9): exit 1 on failure conditions below.

module Shelfstack
  module V0044Verify
    module_function

    LEGACY_PATTERNS = %w[
      catalog_item_identifiers
      CatalogItemIdentifier
      CatalogIdentifierService
      LegacyProductIdentifierBridge
    ].freeze

    # Paths allowed to reference CatalogItem or items_item_path(catalog_item_id:)
    CATALOG_ITEM_ALLOWLIST = [
      "app/models/catalog_item.rb",
      "app/controllers/items/catalog_items_controller.rb",
      "app/controllers/concerns/items/catalog_item_bisac_syncable.rb",
      "app/services/catalog_item_bisac_sync.rb",
      "app/services/catalog_item_store_category_sync.rb",
      "app/services/external_catalog/catalog_item_builder.rb",
      "app/services/external_catalog/staged_catalog_item_builder.rb",
      "app/services/ingram_catalog_import/runner.rb",
      "app/services/products/copy_categorizations_from_catalog_item.rb",
      "app/services/v0042/backfill_product_identifiers.rb",
      "app/controllers/items/items_controller.rb", # legacy redirect shim
      "app/presenters/items/item_presenter.rb", # catalog-only route_params edge case
      "app/services/items/return_path.rb",
      "app/controllers/items/products_controller.rb",
      "app/views/items/catalog_items/",
      "app/views/items/products/",
      "app/models/buyback_line.rb",
      "app/models/external_lookup_result.rb",
      "app/models/category_node.rb",
      "app/services/buybacks/report_builder.rb",
      "app/services/product_bisac_sync.rb",
      "app/controllers/items/external_metadata_controller.rb",
      "app/controllers/concerns/items/setup_modal_locals.rb",
      "app/controllers/items/setup_modals_controller.rb",
      "app/services/external_catalog/import_candidate.rb",
      "app/controllers/items/external_lookup_controller.rb",
      "app/controllers/items/ingram_import_controller.rb",
      "app/services/external_catalog/persist_lookup_result.rb",
      "app/services/external_catalog/duplicate_detector.rb",
      "app/services/external_catalog/lookup_by_isbn.rb",
      "app/services/ingram_catalog_import/import_result.rb",
      "app/services/ingram_catalog_import/product_resolver.rb",
      "app/presenters/items/item_operations_presenter.rb"
    ].freeze

    CATALOG_ITEM_ID_URL_ALLOWLIST = [
      "app/controllers/items/items_controller.rb",
      "app/presenters/items/item_presenter.rb",
      "app/views/items/catalog_items/",
      "app/views/items/external_metadata/show.html.erb",
      "app/controllers/items/external_metadata_controller.rb"
    ].freeze

    BUYBACK_CREATED_CATALOG_ITEM_ALLOWLIST = [
      "app/models/buyback_line.rb",
      "db/schema.rb",
      "test/"
    ].freeze

    def legacy_reference_files
      hits = []
      Dir.glob(Rails.root.join("app/**/*.rb")).each do |path|
        next if path.include?("v0042/backfill_product_identifiers")
        next if path.include?("v0044_verify_wire_through")

        content = File.read(path)
        LEGACY_PATTERNS.each do |pattern|
          hits << "#{path}: #{pattern}" if content.include?(pattern)
        end
      end
      hits
    end

    def catalog_item_reference_files
      hits = []
      Dir.glob(Rails.root.join("app/**/*.rb")).each do |path|
        rel = path.sub("#{Rails.root}/", "")
        next if allowed_path?(rel, CATALOG_ITEM_ALLOWLIST)

        content = File.read(path)
        next unless content.match?(/\bCatalogItem\b/)

        hits << rel
      end
      hits.uniq.sort
    end

    def catalog_item_id_url_files
      hits = []
      patterns = [
        Rails.root.join("app/views/**/*.erb"),
        Rails.root.join("app/helpers/**/*.rb"),
        Rails.root.join("app/presenters/**/*.rb")
      ].each do |glob|
        Dir.glob(glob).each do |path|
          rel = path.sub("#{Rails.root}/", "")
          next if allowed_path?(rel, CATALOG_ITEM_ID_URL_ALLOWLIST)

          content = File.read(path)
          next unless content.include?("items_item_path(catalog_item_id:") ||
                      content.include?("items_item_path( catalog_item_id:")

          hits << rel
        end
      end
      hits.uniq.sort
    end

    def buyback_created_catalog_item_writes
      hits = []
      Dir.glob(Rails.root.join("app/services/buybacks/**/*.rb")).each do |path|
        rel = path.sub("#{Rails.root}/", "")
        content = File.read(path)
        next unless content.match?(/created_catalog_item[_:]/)

        hits << rel unless allowed_path?(rel, BUYBACK_CREATED_CATALOG_ITEM_ALLOWLIST)
      end
      hits.uniq.sort
    end

    def allowed_path?(rel, allowlist)
      allowlist.any? { |entry| rel == entry || rel.start_with?(entry) }
    end

    def audit_table_dated?
      spec = Rails.root.join("docs/v0.04/v0.04-4-variant-grain-wire-through/spec.md")
      return false unless spec.exist?

      content = spec.read
      content.include?("Audit date:") && content.match?(/Audit date: 2026/)
    end
  end
end

namespace :shelfstack do
  namespace :v0044 do
    desc "Verify v0.04-4 variant-grain wire-through (report-only unless STRICT=1)"
    task verify_wire_through: :environment do
      strict = ENV["STRICT"] == "1"
      puts "=== v0.04-4 Variant-Grain Wire-Through Verification ==="
      puts "mode: #{strict ? 'STRICT (merge gate)' : 'report-only'}"

      legacy = Shelfstack::V0044Verify.legacy_reference_files
      puts "legacy identifier references in app/: #{legacy.count}"
      legacy.each { |row| puts "  #{row}" }

      catalog_refs = Shelfstack::V0044Verify.catalog_item_reference_files
      puts "uncategorized CatalogItem references in app/: #{catalog_refs.count}"
      catalog_refs.each { |row| puts "  #{row}" }

      url_refs = Shelfstack::V0044Verify.catalog_item_id_url_files
      puts "items_item_path(catalog_item_id:) outside allowlist: #{url_refs.count}"
      url_refs.each { |row| puts "  #{row}" }

      buyback_writes = Shelfstack::V0044Verify.buyback_created_catalog_item_writes
      puts "buyback services writing created_catalog_item: #{buyback_writes.count}"
      buyback_writes.each { |row| puts "  #{row}" }

      audit_dated = Shelfstack::V0044Verify.audit_table_dated?
      puts "spec audit table dated: #{audit_dated}"

      failures = []
      failures << "legacy identifier references remain" if legacy.any?
      failures << "uncategorized CatalogItem references" if catalog_refs.any?
      failures << "catalog_item_id item URLs outside allowlist" if url_refs.any?
      failures << "buyback intake sets created_catalog_item_id" if buyback_writes.any?
      failures << "spec audit table not dated" if strict && !audit_dated

      if failures.any?
        puts "FAIL: #{failures.join('; ')}"
        exit 1 if strict
        puts "REPORT-ONLY: re-run with STRICT=1 at merge gate"
      else
        puts strict ? "PASS: verification complete" : "REPORT-ONLY: no blocking issues detected (enable STRICT=1 at merge gate)"
      end
    end
  end
end
