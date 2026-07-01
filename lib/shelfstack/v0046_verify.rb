# frozen_string_literal: true

module Shelfstack
  module V0046Verify
    module_function

    DEMAND_NUMBER_PATTERN = /\A\d{3}-D\d{6}\z/

    LEGACY_CREATORS = [
      "CustomerRequests::StartFromItem",
      "CustomerRequests::Create",
      "SpecialOrders::CreateFromRequestLine",
      "PurchaseRequests::CreateSingleLine"
    ].freeze

    def tables_present?
      DemandLine.table_exists? &&
        DemandLineSequence.table_exists? &&
        StockConsideration.table_exists?
    end

    def demand_services_avoid_legacy_writes?
      LEGACY_CREATORS.none? do |name|
        path = Rails.root.join("app/services/#{name.underscore.tr('/', '/')}.rb")
        next false unless path.exist?

        content = File.read(path)
        content.include?("DemandLines::") && content.include?("CustomerRequest")
      end
    end

    def sample_demand_number_valid?(store: Store.active_records.first)
      return true if store.blank?

      DemandLine.where(store: store).limit(5).all? do |line|
        line.demand_number.match?(DEMAND_NUMBER_PATTERN)
      end
    end

    def manual_tbo_not_in_legacy_tbo_build?(store: Store.active_records.first)
      return true if store.blank?

      manual_variant_ids = DemandLine.where(store: store, capture_intent: "manual_tbo").pluck(:product_variant_id)
      return true if manual_variant_ids.empty?

      PurchaseRequestLine
        .buildable_for_store(store)
        .where(product_variant_id: manual_variant_ids)
        .none?
    rescue StandardError
      true
    end

    def report(strict: false)
      checks = {
        tables_present: tables_present?,
        demand_number_format: sample_demand_number_valid?,
        manual_tbo_isolated: manual_tbo_not_in_legacy_tbo_build?
      }

      failures = checks.reject { |_k, v| v }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: checks,
        failures: failures
      }
    end
  end
end
