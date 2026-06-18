# frozen_string_literal: true

module Inventory
  class VariantLookup
    MAX_SEARCH_RESULTS = 25

    Result = Data.define(:status, :variants, :message)

    def self.call(query:, mode: :exact, eligible_only: true)
      new(query:, mode:, eligible_only:).call
    end

    def initialize(query:, mode: :exact, eligible_only: true)
      @query = query.to_s.strip
      @mode = mode.to_sym
      @eligible_only = eligible_only
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

    attr_reader :query, :mode, :eligible_only

    def resolve_exact
      sku_matches = find_by_variant_sku
      return build_result(sku_matches) if sku_matches.any?

      identifier_matches = find_by_catalog_identifiers
      return build_result(identifier_matches) if identifier_matches.any?

      product_sku_matches = find_by_product_sku
      return build_result(product_sku_matches) if product_sku_matches.any?

      Result.new(status: :not_found, variants: [], message: "No matching SKU or barcode found.")
    end

    def search_results
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      variants = base_scope
        .where("product_variants.sku ILIKE :q OR product_variants.name ILIKE :q", q: pattern)
        .order(:sku)
        .limit(MAX_SEARCH_RESULTS)
        .to_a

      if variants.empty?
        Result.new(status: :not_found, variants: [], message: "No variants matched your search.")
      else
        Result.new(status: :search, variants: variants, message: nil)
      end
    end

    def find_by_variant_sku
      base_scope.where("LOWER(product_variants.sku) = ?", query.downcase).to_a
    end

    def find_by_product_sku
      base_scope.where("LOWER(products.sku) = ?", query.downcase).to_a
    end

    def find_by_catalog_identifiers
      digits = normalized_digits(query)
      return [] if digits.blank?

      catalog_item_ids = CatalogItemIdentifier.active_records
        .where(normalized_identifier: digits)
        .select(:catalog_item_id)

      base_scope
        .joins(product: :catalog_item)
        .where(products: { catalog_item_id: catalog_item_ids })
        .distinct
        .to_a
    end

    def build_result(variants)
      if variants.empty?
        Result.new(status: :not_found, variants: [], message: "No matching SKU or barcode found.")
      elsif variants.size == 1
        variant = variants.first
        if !eligible_only || Inventory::Eligibility.eligible?(variant)
          Result.new(status: :found, variants: variants, message: nil)
        else
          Result.new(
            status: :ineligible,
            variants: variants,
            message: "Variant #{variant.sku} is not inventory-eligible (#{variant.inventory_behavior})."
          )
        end
      else
        Result.new(
          status: :ambiguous,
          variants: variants,
          message: "Multiple variants matched. Choose the correct one."
        )
      end
    end

    def base_scope
      ProductVariant.active_records
        .includes(:condition, :product)
        .joins(:product)
        .merge(Product.active_records)
    end

    def normalized_digits(value)
      normalized = CatalogIdentifierService.normalize_preview("isbn13", value).to_s
      return nil if normalized.blank?

      normalized
    end
  end
end
