# frozen_string_literal: true

module Items
  class OperationalWarningBuilder
    Warning = Data.define(:severity, :category, :code, :message, :action_label, :action_path)

    def self.call(product_variant:, contexts: %i[ordering data_quality], vendor: nil, store: nil)
      new(product_variant:, contexts:, vendor:, store:).call
    end

    def initialize(product_variant:, contexts:, vendor: nil, store: nil)
      @product_variant = product_variant
      @contexts = Array(contexts).map(&:to_sym)
      @vendor = vendor
      @store = store
    end

    def call
      warnings = []
      warnings.concat(ordering_warnings) if contexts.include?(:ordering)
      warnings.concat(data_quality_warnings) if contexts.include?(:data_quality)
      warnings
    end

    private

    attr_reader :product_variant, :contexts, :vendor, :store

    def ordering_warnings
      result = Purchasing::OrderEligibilityResolver.call(
        product_variant: product_variant,
        vendor: vendor || suggested_vendor,
        context: :purchase_order,
        store: store
      )

      (result.blocking_reasons + result.warnings + result.infos).map do |reason|
        Warning.new(
          severity: reason.severity,
          category: :ordering,
          code: reason.code,
          message: reason.message,
          action_label: action_for(reason.code)&.dig(:label),
          action_path: action_for(reason.code)&.dig(:path)
        )
      end
    end

    def data_quality_warnings
      []
    end

    def suggested_vendor
      Purchasing::SuggestedVendorResolver.for_variant(product_variant).vendor
    end

    def action_for(code)
      case code
      when :missing_vendor_source, :missing_preferred_vendor
        { label: "Assign vendor", path: Items::VendorSourcingPath.for(product_variant) }
      when :missing_cost
        { label: "Review sourcing", path: Items::VendorSourcingPath.for(product_variant) }
      when :missing_identifier
        { label: "Review identifiers", path: nil }
      end
    end

    include Rails.application.routes.url_helpers
  end
end
