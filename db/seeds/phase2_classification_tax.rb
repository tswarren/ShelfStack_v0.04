# frozen_string_literal: true

require_relative "concerns/csv_classification_importer"

module Seeds
  module Phase2ClassificationTax
    module_function

    def seed!
      CsvClassificationImporter.import_tax_categories!
      CsvClassificationImporter.import_departments!
      CsvClassificationImporter.import_store_tax_rates!
      CsvClassificationImporter.import_store_tax_category_rates!
    end
  end
end
