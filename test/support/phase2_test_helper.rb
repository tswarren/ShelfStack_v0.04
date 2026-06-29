# frozen_string_literal: true

module Phase2TestHelper
  def create_tax_category!(**attrs)
    suffix = SecureRandom.hex(3)
    TaxCategory.create!({
      name: "Test Tax Category #{suffix}",
      short_name: "T#{suffix}",
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
    suffix = SecureRandom.hex(3)
    Department.create!({
      department_number: unique_test_department_number,
      name: "Test Department #{suffix}",
      short_name: "TD#{suffix}",
      active: true
    }.merge(attrs))
  end

  def unique_test_department_number
    loop do
      number = format("%03d", SecureRandom.random_number(900) + 100)
      return number unless Department.exists?(department_number: number)
    end
  end
end
