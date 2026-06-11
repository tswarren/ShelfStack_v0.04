# frozen_string_literal: true

require_relative "seeds/phase1_permissions"
require_relative "seeds/phase2_permissions"
require_relative "seeds/phase3_permissions"
require_relative "seeds/phase3b_permissions"
require_relative "seeds/phase2_classification_tax"
require_relative "seeds/phase3_catalog_products"
require_relative "seeds/phase3b_merchandise_classes"
require_relative "seeds/phase3b_category_schemes"
require_relative "seeds/phase3b_accounting_mappings"
require_relative "seeds/phase3b_templates"

puts "Seeding Phase 1 foundation..."

Seeds::Phase1Permissions.seed!
Seeds::Phase2Permissions.seed!
Seeds::Phase3Permissions.seed!

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
Seeds::Phase3bPermissions.seed!
Seeds::Phase3bTemplates.apply_simple_bookstore!
puts "Phase 3B seed complete."
