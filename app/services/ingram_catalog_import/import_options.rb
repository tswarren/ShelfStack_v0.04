# frozen_string_literal: true

module IngramCatalogImport
  ImportOptions = Struct.new(
    :default_sub_department,
    :default_store_category,
    :default_display_location,
    :set_preferred_vendor,
    :overwrite_existing_preferred_vendor,
    :create_or_update_vendor_sources,
    keyword_init: true
  ) do
    def validate!
      raise ArgumentError, "Default subdepartment is required" if default_sub_department.blank?
      raise ArgumentError, "Default subdepartment must be active" unless default_sub_department.active?
    end

    def set_preferred_vendor?
      set_preferred_vendor == true
    end

    def overwrite_existing_preferred_vendor?
      overwrite_existing_preferred_vendor == true
    end

    def create_or_update_vendor_sources?
      create_or_update_vendor_sources != false
    end
  end
end
