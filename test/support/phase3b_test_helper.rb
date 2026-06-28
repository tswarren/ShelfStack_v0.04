# frozen_string_literal: true

module Phase3bTestHelper
  def create_sub_department!(default_tax_category: nil, department: nil, **attrs)
    default_tax_category ||= create_tax_category!(
      name: "Tax #{SecureRandom.hex(3)}",
      short_name: "T#{SecureRandom.hex(2)}"
    )
    department ||= create_department!(
      department_number: format("%03d", SecureRandom.random_number(900) + 100),
      name: "Test Department #{SecureRandom.hex(2)}",
      short_name: "TD#{SecureRandom.hex(2)}"
    )
    SubDepartment.create!({
      sub_department_key: "test_class_#{SecureRandom.hex(3)}",
      name: "Test Subdepartment #{SecureRandom.hex(2)}",
      short_name: "TSD #{SecureRandom.hex(1)}",
      department: department,
      default_tax_category: default_tax_category,
      active: true
    }.merge(attrs))
  end

  def create_category_scheme!(**attrs)
    defaults = {
      scheme_key: "test_scheme_#{SecureRandom.hex(3)}",
      name: "Test Scheme #{SecureRandom.hex(2)}",
      purpose: "store_categories",
      active: true
    }
    merged = defaults.merge(attrs)
    scheme_key = merged[:scheme_key]

    CategoryScheme.find_or_initialize_by(scheme_key: scheme_key).tap do |scheme|
      scheme.name = merged[:name]
      scheme.purpose = merged[:purpose]
      scheme.active = merged[:active]
      scheme.save!
    end
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
