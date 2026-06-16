# frozen_string_literal: true

module Seeds
  module Phase3bAccountingMappings
    MAPPINGS = [
      {
        sub_department_key: "general_trade_books",
        condition_key: "new",
        sales_account_code: "4100",
        reporting_bucket: "New Book Sales",
        sort_order: 10
      },
      {
        sub_department_key: "used_books",
        sales_account_code: "4200",
        reporting_bucket: "Used Book Sales",
        sort_order: 20
      },
      {
        sub_department_key: "cafe",
        sales_account_code: "4300",
        reporting_bucket: "Cafe Food & Beverage Sales",
        sort_order: 30
      },
      {
        sub_department_key: "gift_cards",
        sales_account_code: "2100",
        reporting_bucket: "Gift Card Liability",
        sort_order: 40
      }
    ].freeze

    module_function

    def seed!
      classes_by_key = SubDepartment.all.index_by(&:sub_department_key)
      conditions_by_key = ProductCondition.all.index_by(&:condition_key)

      MAPPINGS.each do |attrs|
        sub_department = classes_by_key[attrs[:sub_department_key]]
        next if sub_department.blank?

        condition = conditions_by_key[attrs[:condition_key]] if attrs[:condition_key].present?
        mapping = AccountingMapping.find_or_initialize_by(
          sub_department_id: sub_department.id,
          condition_id: condition&.id,
          product_type: attrs[:product_type],
          category_node_id: nil
        )
        mapping.assign_attributes(
          sales_account_code: attrs[:sales_account_code],
          reporting_bucket: attrs[:reporting_bucket],
          gl_export_code: attrs[:gl_export_code],
          description: attrs[:description],
          sort_order: attrs[:sort_order],
          active: true
        )
        mapping.save!
      end
    end
  end
end
