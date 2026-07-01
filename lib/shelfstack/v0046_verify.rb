# frozen_string_literal: true

module Shelfstack
  module V0046Verify
    module_function

    DEMAND_NUMBER_PATTERN = /\A\d{3}-D\d{6}\z/

    V0046_SERVICE_GLOB = "app/services/{demand_lines,stock_considerations}/**/*.rb"

    FORBIDDEN_LEGACY_PATTERNS = [
      /CustomerRequest\b/,
      /CustomerRequestLine\b/,
      /SpecialOrder\b/,
      /SpecialOrders::/,
      /PurchaseRequest\b/,
      /PurchaseRequestLine\b/
    ].freeze

    INVENTORY_POST_PATTERN = /Inventory::Post\b/

    def tables_present?
      DemandLine.table_exists? &&
        DemandLineSequence.table_exists? &&
        StockConsideration.table_exists?
    end

    def demand_service_paths
      Dir.glob(Rails.root.join(V0046_SERVICE_GLOB)).map { |path| path.sub("#{Rails.root}/", "") }.sort
    end

    def demand_services_avoid_legacy_writes?
      demand_service_paths.none? do |rel|
        content = File.read(Rails.root.join(rel))
        FORBIDDEN_LEGACY_PATTERNS.any? { |pattern| content.match?(pattern) }
      end
    end

    def demand_services_avoid_inventory_post?
      demand_service_paths.none? do |rel|
        File.read(Rails.root.join(rel)).match?(INVENTORY_POST_PATTERN)
      end
    end

    def demand_number_format_valid?(store: nil)
      scope = store.present? ? DemandLine.where(store: store) : DemandLine.all
      lines = scope.limit(50).to_a
      return true if lines.empty?

      lines.all? { |line| line.demand_number.match?(DEMAND_NUMBER_PATTERN) }
    end

    def used_wanted_rows_valid?(store: nil)
      scope = used_wanted_scope(store)
      scope.find_each.all? do |line|
        variant = line.product_variant
        next false if variant.blank?

        policy = ProductVariants::OperationalPolicy.for(variant)
        customer_present = line.customer_id.present? || line.customer_name_snapshot.present?
        policy.used_like? && customer_present
      end
    end

    def manual_tbo_rows_vendor_orderable?(store: nil)
      replenishment_scope("manual_tbo", store).find_each.all? do |line|
        variant = line.product_variant
        variant.present? && ProductVariants::OperationalPolicy.for(variant).vendor_orderable?
      end
    end

    def buyer_replenishment_rows_vendor_orderable?(store: nil)
      replenishment_scope("buyer_replenishment", store).find_each.all? do |line|
        variant = line.product_variant
        variant.present? && ProductVariants::OperationalPolicy.for(variant).vendor_orderable?
      end
    end

    def manual_tbo_not_in_legacy_tbo_build?(store: nil)
      stores = store.present? ? [ store ] : Store.active_records.to_a
      stores.all? do |active_store|
        manual_variant_ids = DemandLine.where(store: active_store, capture_intent: "manual_tbo").pluck(:product_variant_id)
        next true if manual_variant_ids.empty?

        PurchaseRequestLine
          .buildable_for_store(active_store)
          .where(product_variant_id: manual_variant_ids)
          .none?
      end
    rescue StandardError
      false
    end

    def report(strict: false)
      checks = {
        tables_present: tables_present?,
        demand_number_format: demand_number_format_valid?,
        demand_services_avoid_legacy_writes: demand_services_avoid_legacy_writes?,
        demand_services_avoid_inventory_post: demand_services_avoid_inventory_post?,
        used_wanted_valid: used_wanted_rows_valid?,
        manual_tbo_vendor_orderable: manual_tbo_rows_vendor_orderable?,
        buyer_replenishment_vendor_orderable: buyer_replenishment_rows_vendor_orderable?,
        manual_tbo_isolated: manual_tbo_not_in_legacy_tbo_build?
      }

      failures = checks.reject { |_key, ok| ok }.keys
      status = failures.empty? ? "PASS" : (strict ? "FAIL" : "WARN")

      {
        status: status,
        checks: checks,
        failures: failures
      }
    end

    def used_wanted_scope(store)
      scope = DemandLine.where(capture_intent: "used_wanted")
      store.present? ? scope.where(store: store) : scope
    end

    def replenishment_scope(capture_intent, store)
      scope = DemandLine.where(capture_intent: capture_intent)
      store.present? ? scope.where(store: store) : scope
    end

    private :used_wanted_scope, :replenishment_scope
  end
end
