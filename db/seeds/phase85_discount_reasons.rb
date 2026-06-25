# frozen_string_literal: true

module Seeds
  module Phase85DiscountReasons
    REASONS = [
      { reason_key: "promotion", name: "Promotion", sort_order: 10, requires_note: false, requires_authorization: false },
      { reason_key: "damaged", name: "Damaged Item", sort_order: 20, requires_note: true, requires_authorization: false },
      { reason_key: "price_match", name: "Price Match", sort_order: 30, requires_note: true, requires_authorization: false },
      { reason_key: "staff_discount", name: "Staff Discount", sort_order: 40, requires_note: false, requires_authorization: false },
      { reason_key: "customer_service", name: "Customer Service Adjustment", sort_order: 50, requires_note: true, requires_authorization: false },
      { reason_key: "manager_adjustment", name: "Manager Adjustment", sort_order: 60, requires_note: false, requires_authorization: true },
      { reason_key: "loyalty", name: "Loyalty Discount", sort_order: 70, requires_note: false, requires_authorization: false },
      { reason_key: "legacy_unspecified", name: "Legacy / Unspecified", sort_order: 80, requires_note: false, requires_authorization: false },
      { reason_key: "other", name: "Other", sort_order: 90, requires_note: true, requires_authorization: false }
    ].freeze

    module_function

    def seed!
      REASONS.each do |attrs|
        DiscountReason.find_or_initialize_by(reason_key: attrs[:reason_key]).tap do |reason|
          reason.name = attrs[:name]
          reason.sort_order = attrs[:sort_order]
          reason.requires_note = attrs[:requires_note]
          reason.requires_authorization = attrs[:requires_authorization]
          reason.active = true
          reason.save!
        end
      end
    end
  end
end
