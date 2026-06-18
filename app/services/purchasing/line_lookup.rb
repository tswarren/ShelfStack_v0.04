# frozen_string_literal: true

module Purchasing
  class LineLookup
    Match = Data.define(:variant, :purchase_order_line)
    Result = Data.define(:status, :matches, :message)

    CONTEXTS = %i[order receive direct_receive rtv].freeze
    OPEN_FOR_RECEIVE_LINE_STATUSES = %w[open partially_received backordered].freeze

    def self.call(store:, query:, mode: :exact, vendor: nil, context: :order, purchase_order: nil, eligible_only: false)
      new(
        store:,
        query:,
        mode:,
        vendor:,
        context:,
        purchase_order:,
        eligible_only:
      ).call
    end

    def initialize(store:, query:, mode: :exact, vendor: nil, context: :order, purchase_order: nil, eligible_only: false)
      @store = store
      @query = query.to_s.strip
      @mode = mode.to_sym
      @vendor = vendor
      @context = context.to_sym
      @purchase_order = purchase_order
      @eligible_only = eligible_only
    end

    def call
      return Result.new(status: :not_found, matches: [], message: "Enter a SKU, vendor item number, or barcode.") if query.blank?

      if mode == :search
        return search_results if query.length >= 2
        return Result.new(status: :not_found, matches: [], message: "Type at least 2 characters to search.")
      end

      resolve_exact
    end

    private

    attr_reader :store, :query, :mode, :vendor, :context, :purchase_order, :eligible_only

    def resolve_exact
      if context == :receive && purchase_order.present?
        po_matches = find_by_open_purchase_order_lines
        return build_result(po_matches) if po_matches.any?
      end

      if vendor.present?
        vendor_matches = find_by_vendor_item_number
        return build_result(vendor_matches) if vendor_matches.any?
      end

      variant_result = Inventory::VariantLookup.call(query:, mode: :exact, eligible_only: eligible_only)
      matches = variant_result.variants.map { |variant| Match.new(variant:, purchase_order_line: nil) }

      Result.new(
        status: variant_result.status,
        matches: matches,
        message: variant_result.message
      )
    end

    def search_results
      variant_result = Inventory::VariantLookup.call(query:, mode: :search, eligible_only: eligible_only)
      matches = variant_result.variants.map { |variant| Match.new(variant:, purchase_order_line: nil) }

      Result.new(
        status: variant_result.status,
        matches: matches,
        message: variant_result.message
      )
    end

    def find_by_open_purchase_order_lines
      open_po_lines.filter_map do |po_line|
        next unless po_line_matches_query?(po_line)

        Match.new(variant: po_line.product_variant, purchase_order_line: po_line)
      end
    end

    def open_po_lines
      return [] if purchase_order.blank?

      purchase_order.purchase_order_lines
        .includes(product_variant: { product: :catalog_item })
        .where(status: OPEN_FOR_RECEIVE_LINE_STATUSES)
        .select { |line| line.quantity_ordered - line.quantity_received > 0 }
    end

    def po_line_matches_query?(po_line)
      variant = po_line.product_variant
      return true if variant.sku.casecmp?(query)

      sourcing = vendor.present? ? SourcingLookup.for(variant:, vendor:) : nil
      return true if sourcing&.vendor_item_number.present? && sourcing.vendor_item_number.casecmp?(query)

      identifier_variants = find_variants_by_catalog_identifier
      identifier_variants.any? { |match| match.id == variant.id }
    end

    def find_by_vendor_item_number
      variant_ids = ProductVariantVendor.active_records
        .where(vendor: vendor)
        .where("LOWER(vendor_item_number) = ?", query.downcase)
        .pluck(:product_variant_id)

      product_ids = ProductVendor.active_records
        .where(vendor: vendor)
        .where("LOWER(vendor_item_number) = ?", query.downcase)
        .pluck(:product_id)

      if product_ids.any?
        variant_ids += ProductVariant.active_records.where(product_id: product_ids).pluck(:id)
      end

      variants = ProductVariant.active_records
        .includes(:condition, :product)
        .where(id: variant_ids.uniq)
        .to_a

      variants.map { |variant| Match.new(variant:, purchase_order_line: nil) }
    end

    def find_variants_by_catalog_identifier
      digits = normalized_digits(query)
      return [] if digits.blank?

      catalog_item_ids = CatalogItemIdentifier.active_records
        .where(normalized_identifier: digits)
        .select(:catalog_item_id)

      ProductVariant.active_records
        .includes(:condition, :product)
        .joins(:product)
        .merge(Product.active_records)
        .where(products: { catalog_item_id: catalog_item_ids })
        .distinct
        .to_a
    end

    def build_result(matches)
      eligible_matches = matches.select { |match| !eligible_only || Inventory::Eligibility.eligible?(match.variant) }

      if eligible_matches.empty?
        if matches.any?
          variant = matches.first.variant
          return Result.new(
            status: :ineligible,
            matches: matches,
            message: "Variant #{variant.sku} is not inventory-eligible (#{variant.inventory_behavior})."
          )
        end

        return Result.new(status: :not_found, matches: [], message: "No matching open PO line found.")
      end

      if eligible_matches.size == 1
        Result.new(status: :found, matches: eligible_matches, message: nil)
      else
        Result.new(
          status: :ambiguous,
          matches: eligible_matches,
          message: "Multiple lines matched. Choose the correct one."
        )
      end
    end

    def normalized_digits(value)
      normalized = CatalogIdentifierService.normalize_preview("isbn13", value).to_s
      return nil if normalized.blank?

      normalized
    end
  end
end
