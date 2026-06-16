# frozen_string_literal: true

module Seeds
  module Phase4Inventory
    REASON_CODES = [
      { reason_key: "opening_balance", name: "Opening Balance", sort_order: 10 },
      { reason_key: "cycle_count", name: "Cycle Count", sort_order: 20 },
      { reason_key: "damage", name: "Damage", sort_order: 30 },
      { reason_key: "shrink", name: "Shrink / Loss", sort_order: 40 },
      { reason_key: "data_correction", name: "Data Correction", sort_order: 50 },
      { reason_key: "recount", name: "Recount Adjustment", sort_order: 60 }
    ].freeze

    DEFAULT_MARGIN_BY_PRICING_MODEL = {
      "trade_discount" => 4000,
      "net_cost_markup" => 5000,
      "blended_lot_cost" => 4500,
      "recipe_cost" => 6000
    }.freeze

    module_function

    def seed!
      seed_reason_codes!
      seed_subdepartment_margins!
    end

    def seed_reason_codes!
      REASON_CODES.each do |attrs|
        InventoryReasonCode.find_or_initialize_by(reason_key: attrs[:reason_key]).tap do |code|
          code.name = attrs[:name]
          code.sort_order = attrs[:sort_order]
          code.active = true
          code.save!
        end
      end
    end

    def seed_subdepartment_margins!
      SubDepartment.find_each do |sub_department|
        next if sub_department.default_margin_target_bps.present?

        margin = DEFAULT_MARGIN_BY_PRICING_MODEL[sub_department.default_pricing_model]
        next if margin.blank?

        sub_department.update!(default_margin_target_bps: margin)
      end
    end
  end
end
