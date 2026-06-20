# frozen_string_literal: true

module Pos
  class LineLookup
    Result = Data.define(:status, :variants, :message)

    def self.call(store:, query:, mode: :exact)
      new(store:, query:, mode:).call
    end

    def initialize(store:, query:, mode: :exact)
      @store = store
      @query = query.to_s.strip
      @mode = mode.to_sym
    end

    def call
      return Result.new(status: :not_found, variants: [], message: "Enter a SKU or barcode.") if query.blank?

      if mode == :search
        return search_results if query.length >= 2

        return Result.new(status: :not_found, variants: [], message: "Type at least 2 characters to search.")
      end

      resolve_exact
    end

    private

    attr_reader :store, :query, :mode

    def resolve_exact
      if barcode_like_query?
        [true, false].each do |active_only|
          matches = find_by_catalog_identifiers(active_only: active_only)
          return build_result(matches) if matches.any?
        end
      end

      [
        -> { find_by_variant_sku(active_only: true) },
        -> { find_by_product_sku(active_only: true) },
        -> { find_by_catalog_identifiers(active_only: true) },
        -> { find_by_variant_sku(active_only: false) },
        -> { find_by_product_sku(active_only: false) },
        -> { find_by_catalog_identifiers(active_only: false) }
      ].each do |finder|
        matches = finder.call
        return build_result(matches) if matches.any?
      end

      Result.new(status: :not_found, variants: [], message: "No matching SKU or barcode found.")
    end

    def barcode_like_query?
      CatalogIdentifierService.lookup_digit_prefix(query).length >= 10
    end

    def search_results
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      variants = active_scope
        .where("product_variants.sku ILIKE :q OR products.sku ILIKE :q OR product_variants.name ILIKE :q", q: pattern)
        .to_a

      variants.concat(find_by_catalog_identifiers_for_search(active_only: true))
      variants = dedupe_variants(variants)

      if variants.empty?
        Result.new(status: :not_found, variants: [], message: "No variants matched your search.")
      else
        Result.new(status: :search, variants: variants.sort_by(&:sku), message: nil)
      end
    end

    def find_by_variant_sku(active_only:)
      lookup_scope(active_only:).where("LOWER(product_variants.sku) = ?", query.downcase).to_a
    end

    def find_by_product_sku(active_only:)
      lookup_scope(active_only:).where("LOWER(products.sku) = ?", query.downcase).to_a
    end

    def find_by_catalog_identifiers(active_only:)
      candidates = CatalogIdentifierService.lookup_candidates(query)
      return [] if candidates.empty?

      identifier_scope = active_only ? CatalogItemIdentifier.active_records : CatalogItemIdentifier.all
      catalog_item_ids = identifier_scope
        .where(normalized_identifier: candidates)
        .select(:catalog_item_id)

      lookup_scope(active_only:).where(products: { catalog_item_id: catalog_item_ids }).distinct.to_a
    end

    def find_by_catalog_identifiers_for_search(active_only:)
      prefix = CatalogIdentifierService.lookup_digit_prefix(query)
      return [] if prefix.blank? || prefix.length < 2

      identifier_scope = active_only ? CatalogItemIdentifier.active_records : CatalogItemIdentifier.all
      catalog_item_ids = identifier_scope
        .where("normalized_identifier LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
        .select(:catalog_item_id)

      lookup_scope(active_only:).where(products: { catalog_item_id: catalog_item_ids }).distinct.to_a
    end

    def build_result(variants)
      variants = dedupe_variants(variants)

      if variants.empty?
        Result.new(status: :not_found, variants: [], message: "No matching SKU or barcode found.")
      elsif variants.size == 1
        Result.new(status: :found, variants: variants, message: nil)
      else
        Result.new(status: :ambiguous, variants: variants, message: "Multiple variants matched. Choose the correct one.")
      end
    end

    def dedupe_variants(variants)
      variants.uniq(&:id)
    end

    def active_scope
      lookup_scope(active_only: true)
    end

    def lookup_scope(active_only:)
      scope = ProductVariant
        .includes(:condition, :product, :sub_department)
        .joins(:product)

      if active_only
        scope.merge(ProductVariant.active_records).merge(Product.active_records)
      else
        scope.where("product_variants.active = ? OR products.active = ?", false, false)
      end
    end
  end
end
