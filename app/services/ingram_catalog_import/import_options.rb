# frozen_string_literal: true

module IngramCatalogImport
  ImportOptions = Struct.new(
    :default_sub_department,
    :default_store_category,
    :default_display_location,
    keyword_init: true
  ) do
    def validate!
      raise ArgumentError, "Default subdepartment is required" if default_sub_department.blank?
      raise ArgumentError, "Default subdepartment must be active" unless default_sub_department.active?
    end
  end
end
