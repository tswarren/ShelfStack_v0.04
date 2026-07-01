# frozen_string_literal: true

module Shelfstack
  module V0045Verify
    module_function

    SKU_211_PATTERN = /\A211[0-9]{10}\z/

    # Paths allowed to call SkuGenerator.variant_sku for new variant creation (legacy preview only)
    SKU_GENERATOR_VARIANT_ALLOWLIST = [
      "app/services/sku_generator.rb",
      "test/",
      "lib/shelfstack/v0045_verify.rb"
    ].freeze

    def new_condition_present?
      ProductCondition.active_records.exists?(new_condition: true, condition_key: "new")
    end

    def buyback_default_valid?
      condition = ProductCondition.find_by(condition_key: "used_good")
      return false if condition.blank?

      condition.active? && condition.buyback_eligible? && condition.buyback_default? && !condition.new_condition?
    end

    def buyback_eligible_marked_new
      ProductCondition.where(buyback_eligible: true, new_condition: true).pluck(:condition_key)
    end

    def used_like_orderable_variant_count
      ProductVariant.active_records
        .joins(:condition)
        .where(product_conditions: { new_condition: false }, orderable: true)
        .count
    end

    def used_like_in_buildable_tbo_count(store: nil)
      store ||= Store.active_records.first
      return 0 if store.blank?

      PurchaseRequestLine
        .buildable_for_store(store)
        .joins(product_variant: :condition)
        .where(product_conditions: { new_condition: false })
        .count
    rescue StandardError
      0
    end

    def buyback_non_211_sku_count
      ProductVariant
        .where(source: "buyback_intake")
        .where.not(sku: nil)
        .find_each
        .count { |variant| variant.sku !~ SKU_211_PATTERN }
    end

    def buyback_new_condition_count
      ProductVariant
        .where(source: "buyback_intake")
        .joins(:condition)
        .where(product_conditions: { new_condition: true })
        .count
    end

    def suffix_sku_generation_paths
      hits = []
      pattern = /SkuGenerator\.variant_sku/

      Dir.glob(Rails.root.join("app/**/*.rb")).each do |path|
        rel = path.sub("#{Rails.root}/", "")
        next if allowed_path?(rel, SKU_GENERATOR_VARIANT_ALLOWLIST)

        content = File.read(path)
        hits << rel if content.match?(pattern)
      end
      hits.uniq.sort
    end

    def allowed_path?(rel, allowlist)
      allowlist.any? { |entry| rel == entry || rel.start_with?(entry) }
    end

    def report
      {
        new_condition_present: new_condition_present?,
        buyback_default_valid: buyback_default_valid?,
        buyback_eligible_marked_new: buyback_eligible_marked_new,
        used_like_orderable_variant_count: used_like_orderable_variant_count,
        used_like_in_buildable_tbo_count: used_like_in_buildable_tbo_count,
        buyback_non_211_sku_count: buyback_non_211_sku_count,
        buyback_new_condition_count: buyback_new_condition_count,
        suffix_sku_generation_paths: suffix_sku_generation_paths
      }
    end

    def strict_failures(report_data = report)
      failures = []
      failures << "active new condition (condition_key: new) missing" unless report_data[:new_condition_present]
      failures << "buyback default condition (used_good) invalid" unless report_data[:buyback_default_valid]
      failures << "buyback_eligible conditions marked new_condition: true" if report_data[:buyback_eligible_marked_new].any?
      failures << "buyback-created variants on new condition" if report_data[:buyback_new_condition_count].positive?
      failures << "suffix SKU generation in app/ outside allowlist" if report_data[:suffix_sku_generation_paths].any?
      failures << "buyback-created variants with non-211 SKU" if report_data[:buyback_non_211_sku_count].positive?
      failures
    end
  end
end
