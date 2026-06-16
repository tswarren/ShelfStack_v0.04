# frozen_string_literal: true

module Seeds
  module Phase3bTemplates
    module_function

    def apply_simple_bookstore!
      Seeds::Phase3bSubDepartments.seed!
      Seeds::Phase3bReferenceTrees.seed!
      Seeds::Phase3bCategorySchemes.deprecate_legacy_nodes!
      Seeds::Phase3bBisac.import!
      Seeds::Phase3CatalogProducts.seed_demo_catalog_and_products!
    end
  end
end
