# frozen_string_literal: true

module IngramCatalogImport
  ImportOptions = Struct.new(:default_category, :default_display_location, keyword_init: true) do
    def validate!
      raise ArgumentError, "Default category is required" if default_category.blank?
      raise ArgumentError, "Default category must be active" unless default_category.active?
    end
  end
end
