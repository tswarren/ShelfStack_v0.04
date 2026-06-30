# frozen_string_literal: true

module Inventory
  class VariantLookup
    MAX_SEARCH_RESULTS = 25

    Result = Data.define(:status, :variants, :message)

    def self.call(query:, mode: :exact, eligible_only: true, store: nil)
      new(query:, mode:, eligible_only:, store:).call
    end

    def initialize(query:, mode: :exact, eligible_only: true, store: nil)
      @query = query.to_s.strip
      @mode = mode.to_sym
      @eligible_only = eligible_only
      @store = store
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

    attr_reader :query, :mode, :eligible_only, :store

    def resolve_exact
      sku_matches = find_by_variant_sku
      return build_result(sku_matches) if sku_matches.any?

      lookup_code_matches = find_by_lookup_code
      return build_result(lookup_code_matches) if lookup_code_matches.any?

      identifier_matches = find_by_product_identifiers
      return build_result(identifier_matches) if identifier_matches.any?

      legacy_product_sku_matches = find_by_legacy_product_sku
      return build_result(legacy_product_sku_matches) if legacy_product_sku_matches.any?

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

    def find_by_lookup_code
      variant = ProductVariants::LookupCodeService.resolve(query, store: store)
      return [] if variant.blank?

      base_scope.where(id: variant.id).to_a
    end

    def find_by_legacy_product_sku
      base_scope
        .left_joins(product: :product_identifiers)
        .where("LOWER(products.sku) = ?", query.downcase)
        .where(product_identifiers: { id: nil })
        .to_a
    end

    def find_by_product_identifiers
      normalized = ProductIdentifierService.lookup_digit_prefix(query)
      return [] if normalized.blank?

      products = Items::ProductIdentifierLookup.find_products_by_query(normalized, active_only: true)
      return [] if products.none?

      base_scope.where(product_id: products.select(:id)).distinct.to_a
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
  end
end
