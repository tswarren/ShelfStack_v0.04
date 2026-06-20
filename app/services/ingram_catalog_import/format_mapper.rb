# frozen_string_literal: true

module IngramCatalogImport
  class FormatMapper
    class FormatError < StandardError; end

    def self.resolve!(format_name)
      CatalogImport::BindingFormatMapper.resolve!(format_name)
    rescue CatalogImport::BindingFormatMapper::FormatError => e
      raise FormatError, e.message
    end

    def initialize(format_name)
      @format_name = format_name
    end

    def resolve!
      self.class.resolve!(@format_name)
    end
  end
end
