# frozen_string_literal: true

require_relative "seeds/phase1_permissions"
require_relative "seeds/phase2_permissions"
require_relative "seeds/phase3_permissions"
require_relative "seeds/phase3b_permissions"
require_relative "seeds/phase4_permissions"
require_relative "seeds/phase5_permissions"
require_relative "seeds/phase6_permissions"
require_relative "seeds/phase65_permissions"
require_relative "seeds/phase7a_permissions"
require_relative "seeds/phase7b_permissions"
require_relative "seeds/phase7b_stored_value"
require_relative "seeds/phase7c_permissions"
require_relative "seeds/phase7c_buyback"
require_relative "seeds/phase85_permissions"
require_relative "seeds/phase6_roles"
require_relative "seeds/phase2_classification_tax"
require_relative "seeds/phase3_catalog_products"
require_relative "seeds/phase3b_sub_departments"
require_relative "seeds/phase3b_reference_trees"
require_relative "seeds/phase3b_category_schemes"
require_relative "seeds/phase3b_bisac"
require_relative "seeds/phase3b_templates"
require_relative "seeds/phase4_inventory"
require_relative "seeds/phase5_inventory"
require_relative "seeds/phase85_discount_reasons"
require_relative "seeds/phase852_permissions"
require_relative "seeds/phase9a_permissions"
require_relative "seeds/phase852_tax_exception_reasons"

puts "Seeding Phase 1 foundation..."

Seeds::Phase1Permissions.seed!
Seeds::Phase2Permissions.seed!
Seeds::Phase3Permissions.seed!
Seeds::Phase3bPermissions.seed!
Seeds::Phase4Permissions.seed!
Seeds::Phase5Permissions.seed!
Seeds::Phase6Permissions.seed!
Seeds::Phase65Permissions.seed!
Seeds::Phase7aPermissions.seed!
Seeds::Phase7bPermissions.seed!
Seeds::Phase7cPermissions.seed!
Seeds::Phase85Permissions.seed!
Seeds::Phase852Permissions.seed!
Seeds::Phase6Roles.seed!

system_user = User.find_or_initialize_by(username: "system")
system_user.assign_attributes(
  user_type: "system",
  first_name: "ShelfStack",
  last_name: "System Account",
  display_name: "ShelfStack System",
  interactive_login_enabled: false,
  active: true,
  password: SecureRandom.hex(32)
)
system_user.save!

admin_password = "ChangeMe#{rand(100..999)}!"
admin_user = User.find_or_initialize_by(username: "admin")
admin_password_set = admin_user.new_record?

admin_attrs = {
  user_type: "admin",
  first_name: "ShelfStack",
  last_name: "Administrator",
  display_name: "Administrator",
  clerk_number: "00001",
  force_password_change: true,
  interactive_login_enabled: true,
  active: true
}
admin_attrs[:password] = admin_password if admin_password_set
admin_user.assign_attributes(admin_attrs)
admin_user.save!

super_admin_role = Role.find_or_initialize_by(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY)
super_admin_role.assign_attributes(
  name: "Super Administrator",
  description: "Full system access",
  system_role: true,
  active: true
)
super_admin_role.save!

Permission.active_records.find_each do |permission|
  super_admin_role.grant_permission!(permission)
end

SuperAdministratorProtection.restore!

UserRoleAssignment.find_or_initialize_by(
  user: admin_user,
  role: super_admin_role,
  scope_type: "global"
).tap do |assignment|
  assignment.active = true
  assignment.assigned_at = Time.current
  assignment.save!
end

stores_data = [
  {
    store_number: "001", store_group: "00001", name: "ShelfStack Books - Main",
    shopping_center: "Downtown Shopping District", address_line1: "123 Main St",
    city: "Bloomfield Hills", country_code: "US", region_code: "MI", postal_code: "48302",
    phone: "947-555-2665", fax: "947-555-2660", email: "store001@shelfstack.demo",
    website_url: "https://www.shelfstack.demo", time_zone: "America/New_York", active: true
  },
  {
    store_number: "002", store_group: "00001", name: "ShelfStack Books - Branch",
    address_line1: "999 First Ave", city: "Los Angeles", country_code: "US",
    region_code: "CA", postal_code: "90210", phone: "310-555-2665", fax: "310-555-2660",
    email: "store002@shelfstack.demo", website_url: "https://www.shelfstack.demo",
    time_zone: "America/Los_Angeles", active: true
  }
]

stores_data.each do |attrs|
  Store.find_or_initialize_by(store_number: attrs[:store_number]).tap do |store|
    store.assign_attributes(attrs)
    store.save!
  end
end

Store.find_each do |store|
  [
    { type: "register", number: "001", code_suffix: "REG001", name: "Front Register" },
    { type: "service_desk", number: "002", code_suffix: "SVC001", name: "Service Desk" }
  ].each do |ws|
    code = "#{store.store_number}-#{ws[:code_suffix]}"
    Workstation.find_or_initialize_by(store: store, workstation_code: code).tap do |workstation|
      workstation.workstation_type = ws[:type]
      workstation.workstation_number = ws[:number]
      workstation.name = ws[:name]
      workstation.active = true
      workstation.save!
    end
  end
end

if Rails.env.development?
  if admin_password_set
    puts "Seeded admin user: admin / #{admin_password}"
  else
    puts "Admin user already exists (username: admin). Password unchanged."
  end
elsif !Rails.env.test?
  puts "Admin user: admin (#{admin_password_set ? "password reset" : "unchanged"})"
end

puts "Phase 1 seed complete."

puts "Seeding Phase 2 classification and tax..."
Seeds::Phase2ClassificationTax.seed!
puts "Phase 2 seed complete."

puts "Seeding Phase 3 catalog, products, and variants..."
Seeds::Phase3CatalogProducts.seed!
puts "Phase 3 seed complete."

puts "Seeding Phase 3B merchandise classification..."
Seeds::Phase3bTemplates.apply_simple_bookstore!

super_admin_role = Role.find_by!(role_key: ShelfStack::SUPER_ADMINISTRATOR_ROLE_KEY)
Permission.active_records.find_each { |permission| super_admin_role.grant_permission!(permission) }
SuperAdministratorProtection.restore!

puts "Phase 3B seed complete."

puts "Seeding Phase 4 inventory..."
Seeds::Phase4Inventory.seed!
puts "Phase 4 seed complete."

puts "Seeding Phase 5 purchasing..."
Seeds::Phase5Inventory.seed!
puts "Phase 5 seed complete."

puts "Seeding Phase 7B stored value..."
Seeds::Phase7bStoredValue.seed!
puts "Phase 7B stored value seed complete."

puts "Seeding Phase 7C buyback..."
Seeds::Phase7cBuyback.seed!
puts "Phase 7C buyback seed complete."

puts "Seeding Phase 8.5-1 discount reasons..."
Seeds::Phase85DiscountReasons.seed!
puts "Phase 8.5-1 discount reasons seed complete."

puts "Seeding Phase 8.5-2 tax exception reasons..."
Seeds::Phase852TaxExceptionReasons.seed!
puts "Phase 8.5-2 tax exception reasons seed complete."

ExternalDataSource.find_or_initialize_by(source_key: "isbndb").tap do |source|
  source.assign_attributes(
    name: "ISBNdb",
    base_url: "https://api2.isbndb.com",
    active: true,
    configuration_json: {}
  )
  source.save!
end
puts "Phase 6.5 external data sources seed complete."
