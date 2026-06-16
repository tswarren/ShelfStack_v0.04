# frozen_string_literal: true

require_relative "concerns/csv_classification_importer"

module Seeds
  module Phase3bSubDepartments
    module_function

    def seed!
      CsvClassificationImporter.import_sub_departments!
    end
  end
end
