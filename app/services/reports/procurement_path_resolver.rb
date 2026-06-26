# frozen_string_literal: true

module Reports
  class ProcurementPathResolver
    PATHS = %w[
      vendor_order
      buyback
      donation
      buyback_donation
      manual_stock
      not_applicable
    ].freeze

    def self.call(product_variant:, buyback_line: nil, line_type: nil)
      new(product_variant:, buyback_line:, line_type:).call
    end

    def initialize(product_variant:, buyback_line: nil, line_type: nil)
      @variant = product_variant
      @product = product_variant&.product
      @buyback_line = buyback_line
      @line_type = line_type
    end

    def call
      return "not_applicable" if @variant.blank?
      return "not_applicable" if @line_type == "gift_card_sale"
      return "not_applicable" if not_applicable_product?

      return "buyback_donation" if buyback_donation?
      return "buyback" if buyback_sourced?
      return "vendor_order" if vendor_sourced?
      return "manual_stock" if inventory_eligible?

      "not_applicable"
    end

    private

    attr_reader :variant, :product, :buyback_line, :line_type

    def not_applicable_product?
      product.product_type.in?(%w[service financial non_inventory]) ||
        !Inventory::Eligibility.eligible?(variant)
    end

    def buyback_donation?
      return false if buyback_line.blank?

      buyback_line.outcome == "donated_by_customer" ||
        (buyback_line.outcome == "accepted_by_customer" && buyback_line.accepted_offer_cents.to_i.zero?)
    end

    def buyback_sourced?
      variant.created_from_buyback_session_id.present? ||
        product.created_from_buyback_session_id.present?
    end

    def vendor_sourced?
      variant.orderable? ||
        variant.preferred_vendor_id.present? ||
        product.preferred_vendor_id.present? ||
        variant.product_variant_vendors.exists? ||
        product.product_vendors.exists?
    end

    def inventory_eligible?
      Inventory::Eligibility.eligible?(variant)
    end
  end
end
