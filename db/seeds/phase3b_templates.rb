# frozen_string_literal: true

module Seeds
  module Phase3bTemplates
    module_function

    def apply_simple_bookstore!
      Seeds::Phase3bMerchandiseClasses.seed!
      Seeds::Phase3bCategorySchemes.seed!
      Seeds::Phase3bAccountingMappings.seed!
    end
  end
end
