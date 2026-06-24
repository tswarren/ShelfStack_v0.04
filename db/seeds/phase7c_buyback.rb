# frozen_string_literal: true

module Seeds
  module Phase7cBuyback
    REJECT_REASONS = [
      { reason_key: "poor_condition", name: "Poor condition", sort_order: 1 },
      { reason_key: "not_needed", name: "Not needed", sort_order: 2 },
      { reason_key: "overstocked", name: "Overstocked", sort_order: 3 },
      { reason_key: "not_resellable", name: "Not resellable", sort_order: 4 },
      { reason_key: "missing_components", name: "Missing components", sort_order: 5 },
      { reason_key: "outdated", name: "Outdated", sort_order: 6 },
      { reason_key: "duplicate_copy", name: "Duplicate copy", sort_order: 7 },
      { reason_key: "counterfeit_or_suspicious", name: "Counterfeit or suspicious", sort_order: 8 },
      { reason_key: "other", name: "Other", sort_order: 99 }
    ].freeze

    BUYBACK_CONDITION_FLAGS = {
      "used_like_new" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: false, buyback_sort_order: 11 },
      "used_very_fine" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: false, buyback_sort_order: 12 },
      "used_fine" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: false, buyback_sort_order: 13 },
      "used_good" => { buyback_eligible: true, buyback_default: true, buyback_requires_review: false, buyback_sort_order: 14 },
      "used_poor" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: false, buyback_sort_order: 15 },
      "used_ex_library" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: true, buyback_sort_order: 16 },
      "used_book_club" => { buyback_eligible: true, buyback_default: false, buyback_requires_review: true, buyback_sort_order: 17 },
      "new" => { buyback_eligible: false, buyback_default: false, buyback_requires_review: false },
      "signed_copy" => { buyback_eligible: false, buyback_default: false, buyback_requires_review: false },
      "special_edition" => { buyback_eligible: false, buyback_default: false, buyback_requires_review: false },
      "remainder" => { buyback_eligible: false, buyback_default: false, buyback_requires_review: false }
    }.freeze

    def self.seed!
      seed_condition_flags!
      seed_reject_reasons!
      seed_pricing_rules!
    end

    def self.seed_condition_flags!
      BUYBACK_CONDITION_FLAGS.each do |condition_key, flags|
        condition = ProductCondition.find_by(condition_key: condition_key)
        next if condition.blank?

        condition.update!(flags)
      end
    end

    def self.seed_reject_reasons!
      REJECT_REASONS.each do |attrs|
        BuybackRejectReason.find_or_initialize_by(reason_key: attrs[:reason_key]).tap do |reason|
          reason.name = attrs[:name]
          reason.sort_order = attrs[:sort_order]
          reason.active = true
          reason.save!
        end
      end
    end

    def self.seed_pricing_rules!
      return if BuybackPricingRule.exists?

      sub = SubDepartment.find_by(sub_department_key: "general_trade")
      good = ProductCondition.find_by(condition_key: "used_good")
      return if sub.blank? || good.blank?

      BuybackPricingRule.create!(
        name: "Default trade books - Good",
        sub_department: sub,
        product_condition: good,
        base_price_source: "variant_selling_price",
        resale_price_factor_bps: 6000,
        cash_offer_bps: 2500,
        trade_credit_offer_bps: 3500,
        minimum_offer_cents: 25,
        rounding_increment_cents: 25,
        active: true,
        sort_order: 0
      )

      BuybackPricingRule.create!(
        name: "Default trade books - broad",
        sub_department: sub,
        product_condition: nil,
        base_price_source: "product_list_price",
        resale_price_factor_bps: 5000,
        cash_offer_bps: 2000,
        trade_credit_offer_bps: 3000,
        minimum_offer_cents: 25,
        rounding_increment_cents: 25,
        active: true,
        sort_order: 10
      )
    end
  end
end
