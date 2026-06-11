# frozen_string_literal: true

module Phase3bTestHelper
  def create_merchandise_class!(default_tax_category: nil, **attrs)
    default_tax_category ||= create_tax_category!
    MerchandiseClass.create!({
      merchandise_class_key: "test_class_#{SecureRandom.hex(3)}",
      name: "Test Merchandise Class #{SecureRandom.hex(2)}",
      short_name: "Test MC #{SecureRandom.hex(1)}",
      default_tax_category: default_tax_category,
      active: true
    }.merge(attrs))
  end

  def create_category_scheme!(**attrs)
    CategoryScheme.create!({
      scheme_key: "test_scheme_#{SecureRandom.hex(3)}",
      name: "Test Scheme #{SecureRandom.hex(2)}",
      purpose: "store_sections_topics",
      active: true
    }.merge(attrs))
  end

  def create_category_node!(category_scheme: nil, **attrs)
    category_scheme ||= create_category_scheme!
    CategoryNode.create!({
      category_scheme: category_scheme,
      node_key: "test_node_#{SecureRandom.hex(3)}",
      name: "Test Node #{SecureRandom.hex(2)}",
      sort_order: 0,
      active: true
    }.merge(attrs))
  end

  def grant_all_phase3b_permissions!(user, store: nil)
    Seeds::Phase3bPermissions.seed!
    Seeds::Phase3bPermissions::PERMISSIONS.each do |permission|
      grant_permission!(user, permission[:key], store: store)
    end
  end

  def seed_bisac_scheme!(path: Rails.root.join("test/fixtures/files/bisac_sample.csv"))
    Bisac::CategoryNodeImporter.call(path: path)
  end
end
