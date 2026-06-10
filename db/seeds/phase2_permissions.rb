# frozen_string_literal: true

module Seeds
  module Phase2Permissions
    PERMISSIONS = [
      { key: "setup.tax_categories.view", group: "setup", name: "View Tax Categories", description: "View tax categories" },
      { key: "setup.tax_categories.create", group: "setup", name: "Create Tax Categories", description: "Create tax categories" },
      { key: "setup.tax_categories.update", group: "setup", name: "Update Tax Categories", description: "Update tax categories" },
      { key: "setup.tax_categories.inactivate", group: "setup", name: "Inactivate Tax Categories", description: "Inactivate tax categories" },
      { key: "setup.tax_categories.reactivate", group: "setup", name: "Reactivate Tax Categories", description: "Reactivate tax categories" },
      { key: "setup.tax_categories.delete", group: "setup", name: "Delete Tax Categories", description: "Delete unused tax categories" },
      { key: "setup.store_tax_rates.view", group: "setup", name: "View Store Tax Rates", description: "View store tax rates" },
      { key: "setup.store_tax_rates.create", group: "setup", name: "Create Store Tax Rates", description: "Create store tax rates" },
      { key: "setup.store_tax_rates.update", group: "setup", name: "Update Store Tax Rates", description: "Update store tax rates" },
      { key: "setup.store_tax_rates.inactivate", group: "setup", name: "Inactivate Store Tax Rates", description: "Inactivate store tax rates" },
      { key: "setup.store_tax_rates.reactivate", group: "setup", name: "Reactivate Store Tax Rates", description: "Reactivate store tax rates" },
      { key: "setup.store_tax_rates.delete", group: "setup", name: "Delete Store Tax Rates", description: "Delete unused store tax rates" },
      { key: "setup.store_tax_category_rates.view", group: "setup", name: "View Tax Mappings", description: "View store tax category rate mappings" },
      { key: "setup.store_tax_category_rates.create", group: "setup", name: "Create Tax Mappings", description: "Create store tax category rate mappings" },
      { key: "setup.store_tax_category_rates.update", group: "setup", name: "Update Tax Mappings", description: "Update store tax category rate mappings" },
      { key: "setup.store_tax_category_rates.inactivate", group: "setup", name: "Inactivate Tax Mappings", description: "Inactivate store tax category rate mappings" },
      { key: "setup.store_tax_category_rates.reactivate", group: "setup", name: "Reactivate Tax Mappings", description: "Reactivate store tax category rate mappings" },
      { key: "setup.store_tax_category_rates.delete", group: "setup", name: "Delete Tax Mappings", description: "Delete unused store tax category rate mappings" },
      { key: "setup.departments.view", group: "setup", name: "View Departments", description: "View departments" },
      { key: "setup.departments.create", group: "setup", name: "Create Departments", description: "Create departments" },
      { key: "setup.departments.update", group: "setup", name: "Update Departments", description: "Update departments" },
      { key: "setup.departments.inactivate", group: "setup", name: "Inactivate Departments", description: "Inactivate departments" },
      { key: "setup.departments.reactivate", group: "setup", name: "Reactivate Departments", description: "Reactivate departments" },
      { key: "setup.departments.delete", group: "setup", name: "Delete Departments", description: "Delete unused departments" },
      { key: "setup.categories.view", group: "setup", name: "View Categories", description: "View categories" },
      { key: "setup.categories.create", group: "setup", name: "Create Categories", description: "Create categories" },
      { key: "setup.categories.update", group: "setup", name: "Update Categories", description: "Update categories" },
      { key: "setup.categories.inactivate", group: "setup", name: "Inactivate Categories", description: "Inactivate categories" },
      { key: "setup.categories.reactivate", group: "setup", name: "Reactivate Categories", description: "Reactivate categories" },
      { key: "setup.categories.delete", group: "setup", name: "Delete Categories", description: "Delete unused categories" }
    ].freeze

    def self.seed!
      PERMISSIONS.each do |attrs|
        Permission.find_or_initialize_by(permission_key: attrs[:key]).tap do |permission|
          permission.permission_group = attrs[:group]
          permission.name = attrs[:name]
          permission.description = attrs[:description]
          permission.active = true
          permission.save!
        end
      end
    end
  end
end
