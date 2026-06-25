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
      catalog_item = find_by_identifier
      catalog_item ||= find_by_title if title.present?
      return Result.new(catalog_item: nil, product: nil, variants: [], warnings: []) if catalog_item.blank?

      product = catalog_item.products.active_records.first
      variants = product&.product_variants&.active_records&.includes(:condition) || []
      eligible = variants.select { |v| variant_eligible?(v) }
      warnings = variants.reject { |v| variant_eligible?(v) }.map do |v|
        "#{v.name} — not eligible for buyback"
      end

      Result.new(catalog_item:, product:, variants: eligible, warnings:)
    end

    private

    attr_reader :store, :identifier, :title

    def find_by_identifier
      return if identifier.blank?

      normalized = identifier.upcase.gsub(/[^0-9X]/i, "")
      ident = CatalogItemIdentifier.active_records.find_by(normalized_identifier: normalized)
      ident&.catalog_item
    end

    def find_by_title
      CatalogItem.active_records.where("title ILIKE ?", "%#{title}%").first
    end

    def variant_eligible?(variant)
      Inventory::Eligibility.eligible?(variant) &&
        variant.condition&.buyback_eligible? &&
        variant.sub_department&.buyback_allowed?
    end
  end
end
