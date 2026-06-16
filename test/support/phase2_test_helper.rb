# frozen_string_literal: true

module Phase2TestHelper
  def create_tax_category!(**attrs)
    TaxCategory.create!({
      name: "Test Tax Category",
      short_name: "Test",
      sort_order: 10,
      active: true
    }.merge(attrs))
  end

  def create_store_tax_rate!(store: nil, **attrs)
    store ||= create_store!
    StoreTaxRate.create!({
      store: store,
      name: "Taxable",
      short_name: "Taxable",
      tax_identifier: "T",
      tax_rate_bps: 600,
      active: true
    }.merge(attrs))
  end

  def create_store_tax_category_rate!(store: nil, tax_category: nil, store_tax_rate: nil, **attrs)
    store ||= create_store!
    tax_category ||= create_tax_category!
    store_tax_rate ||= create_store_tax_rate!(store: store)
    StoreTaxCategoryRate.create!({
      store: store,
      tax_category: tax_category,
      store_tax_rate: store_tax_rate,
      effective_on: Date.new(2026, 1, 1),
      active: true
    }.merge(attrs))
  end

  def create_department!(**attrs)
    Department.create!({
      department_number: "099",
      name: "Test Department",
      short_name: "Test Dept",
      active: true
    }.merge(attrs))
  end
end
