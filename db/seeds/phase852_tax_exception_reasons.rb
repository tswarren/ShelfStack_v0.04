# frozen_string_literal: true

module Seeds
  module Phase852TaxExceptionReasons
    REASONS = [
      { reason_key: "resale", name: "Resale Certificate", exception_type: "exemption", sort_order: 10, requires_note: false, requires_certificate: true },
      { reason_key: "nonprofit", name: "Nonprofit Exemption", exception_type: "exemption", sort_order: 20, requires_note: false, requires_certificate: true },
      { reason_key: "school", name: "School Exemption", exception_type: "exemption", sort_order: 30, requires_note: false, requires_certificate: true },
      { reason_key: "government", name: "Government Exemption", exception_type: "exemption", sort_order: 40, requires_note: false, requires_certificate: true },
      { reason_key: "out_of_state", name: "Out of State / Not Taxable", exception_type: "exemption", sort_order: 50, requires_note: true, requires_certificate: false },
      { reason_key: "wrong_tax_category", name: "Wrong Tax Category", exception_type: "rate_override", sort_order: 60, requires_note: true, requires_certificate: false },
      { reason_key: "manual_correction", name: "Manual Tax Correction", exception_type: "rate_override", sort_order: 70, requires_note: true, requires_certificate: false },
      { reason_key: "manager_adjustment", name: "Manager Tax Adjustment", exception_type: "both", sort_order: 80, requires_note: false, requires_certificate: false },
      { reason_key: "other", name: "Other", exception_type: "both", sort_order: 90, requires_note: true, requires_certificate: false }
    ].freeze

    module_function

    def seed!
      REASONS.each do |attrs|
        TaxExceptionReason.find_or_initialize_by(reason_key: attrs[:reason_key]).tap do |reason|
          reason.name = attrs[:name]
          reason.exception_type = attrs[:exception_type]
          reason.sort_order = attrs[:sort_order]
          reason.requires_note = attrs[:requires_note]
          reason.requires_certificate = attrs[:requires_certificate]
          reason.active = true
          reason.save!
        end
      end
    end
  end
end
