# frozen_string_literal: true

module Sourcing
  class SuggestVendors
    Candidate = Data.define(:vendor, :suggestion, :source_level, :warnings)

    def self.call!(variant:, manual_vendor: nil)
      new(variant:, manual_vendor:).call!
    end

    def initialize(variant:, manual_vendor: nil)
      @variant = variant
      @manual_vendor = manual_vendor
    end

    def call!
      if manual_vendor.present?
        return [ manual_candidate(manual_vendor) ]
      end

      suggestion = Purchasing::SuggestedVendorResolver.for_variant(variant)
      return [] if suggestion.vendor.blank?

      [ build_candidate(suggestion) ]
    end

    private

    attr_reader :variant, :manual_vendor

    def build_candidate(suggestion)
      vendor = suggestion.vendor
      warnings = []
      warnings << "Vendor is inactive" unless vendor.active?
      pvv = suggestion.product_variant_vendor
      pv = suggestion.product_vendor
      vendor_item_number = pvv&.vendor_item_number || pv&.vendor_item_number
      warnings << "Missing vendor item number" if vendor_item_number.blank?

      source_level = VendorSourceSnapshot.map_source_level(suggestion.source)
      Candidate.new(
        vendor: vendor,
        suggestion: suggestion,
        source_level: source_level,
        warnings: warnings
      )
    end

    def manual_candidate(vendor)
      warnings = []
      warnings << "Vendor is inactive" unless vendor.active?
      suggestion = Purchasing::SuggestedVendorResolver::Result.new(
        vendor: vendor,
        product_variant_vendor: nil,
        product_vendor: nil,
        source: "manual"
      )
      Candidate.new(
        vendor: vendor,
        suggestion: suggestion,
        source_level: "manual",
        warnings: warnings
      )
    end
  end
end
