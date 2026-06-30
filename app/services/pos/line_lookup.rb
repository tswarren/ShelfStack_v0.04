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
      [ true, false ].each do |active_only|
        [
          -> { find_by_variant_sku(active_only:) },
          -> { find_by_lookup_code(active_only:) },
          -> { find_by_product_identifiers(active_only:) },
          -> { find_by_legacy_product_sku(active_only:) }
        ].each do |finder|
          matches = finder.call
          return build_result(matches) if matches.any?
        end
      end

      Result.new(status: :not_found, variants: [], message: "No matching SKU or barcode found.")
    end

    def search_results
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      variants = active_scope
        .where("product_variants.sku ILIKE :q OR product_variants.name ILIKE :q", q: pattern)
        .to_a

      variants.concat(find_by_product_identifiers_for_search(active_only: true))
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

    def find_by_lookup_code(active_only:)
      variant = ProductVariants::LookupCodeService.resolve(query, store: store)
      return [] if variant.blank?

      lookup_scope(active_only:).where(id: variant.id).to_a
    end

    def find_by_product_identifiers(active_only:)
      normalized = ProductIdentifierService.lookup_digit_prefix(query)
      return [] if normalized.blank?

      products = Items::ProductIdentifierLookup.find_products_by_query(normalized, active_only: active_only)
      return [] if products.none?

      lookup_scope(active_only:).where(product_id: products.select(:id)).distinct.to_a
    end

    def find_by_legacy_product_sku(active_only:)
      lookup_scope(active_only:)
        .left_joins(product: :product_identifiers)
        .where("LOWER(products.sku) = ?", query.downcase)
        .where(product_identifiers: { id: nil })
        .to_a
    end

    def find_by_product_identifiers_for_search(active_only:)
      prefix = ProductIdentifierService.lookup_digit_prefix(query)
      return [] if prefix.blank? || prefix.length < 2

      identifier_scope = active_only ? ProductIdentifier.active_records : ProductIdentifier.all
      product_ids = identifier_scope
        .where("normalized_identifier LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
        .select(:product_id)

      lookup_scope(active_only:).where(product_id: product_ids).distinct.to_a
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
