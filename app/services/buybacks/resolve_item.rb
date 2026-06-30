# frozen_string_literal: true

module Buybacks
  class ResolveItem
    Result = Data.define(:catalog_item, :product, :variants, :warnings)

    def self.call(store:, identifier: nil, title: nil)
      new(store:, identifier:, title:).call
    end

    def initialize(store:, identifier: nil, title: nil)
      @store = store
      @identifier = identifier&.strip
      @title = title&.strip
    end

    def call
      product = find_by_identifier
      product ||= find_by_title if title.present?
      return Result.new(catalog_item: nil, product: nil, variants: [], warnings: []) if product.blank?

      variants = product.product_variants.active_records.includes(:condition) || []
      eligible = variants.select { |v| variant_eligible?(v) }
      warnings = variants.reject { |v| variant_eligible?(v) }.map do |v|
        "#{v.name} — not eligible for buyback"
      end

      Result.new(catalog_item: product.catalog_item, product:, variants: eligible, warnings:)
    end

    private

    attr_reader :store, :identifier, :title

    def find_by_identifier
      return if identifier.blank?

      normalized = identifier.upcase.gsub(/[^0-9X]/i, "")
      product = Product.find_by(sku: normalized)
      return product if product.present?

      Items::ProductIdentifierLookup.find_products_by_identifier_query(normalized).order(:id).first
    end

    def find_by_title
      Product.active_records.where("title ILIKE ?", "%#{title}%").order(:id).first
    end

    def variant_eligible?(variant)
      Inventory::Eligibility.eligible?(variant) &&
        variant.condition&.buyback_eligible? &&
        variant.sub_department&.buyback_allowed?
    end
  end
end
