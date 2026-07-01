# frozen_string_literal: true

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
        next if path.include?("v0044_verify")

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
      [
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
