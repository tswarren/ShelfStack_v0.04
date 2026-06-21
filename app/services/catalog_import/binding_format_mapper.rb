# frozen_string_literal: true

module CatalogImport
  class BindingFormatMapper
    class FormatError < StandardError; end

    FORMAT_KEYS = {
      "hardcover" => "hardcover",
      "paperback" => "trade_paperback",
      "trade paperback" => "trade_paperback",
      "mass market paperback" => "mass_market_paperback",
      "mass market" => "mass_market_paperback",
      "board books" => "trade_paperback",
      "board book" => "trade_paperback",
      "compact disc" => "compact_disc",
      "cd" => "compact_disc",
      "dvd" => "dvd",
      "ebook" => "ebook",
      "e book" => "ebook",
      "digital audiobook" => "audiobook_digital",
      "audiobook" => "audiobook_digital",
      "calendar" => "calendar",
      "magazine" => "magazine"
    }.freeze

    def self.resolve!(format_name)
      new(format_name).resolve!
    end

    def self.resolve(format_name)
      new(format_name).resolve
    end

    def initialize(format_name)
      @format_name = format_name.to_s.strip
    end

    def resolve!
      format = resolve
      raise FormatError, "Unmapped binding/format: #{@format_name}" if format.blank?

      format
    end

    def resolve
      return nil if @format_name.blank?

      format_key = FORMAT_KEYS[normalized_name]
      return nil if format_key.blank?

      Format.active_records.find_by(format_key: format_key)
    end

    private

    def normalized_name
      @format_name.downcase.squeeze(" ")
    end
  end
end
