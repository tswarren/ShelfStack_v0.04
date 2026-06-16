# frozen_string_literal: true

require "roo"
require "roo-xls"

module IngramCatalogImport
  class SpreadsheetParser
    class ParseError < StandardError; end

    REQUIRED_HEADERS = [
      "Product Code",
      "EAN",
      "Product Name",
      "Contributor",
      "Product Type",
      "Format",
      "Supplier",
      "Pub Date",
      "Series",
      "BISAC Category",
      "US SRP",
      "Weight"
    ].freeze

    HEADER_INDEX = {
      product_code: 0,
      ean: 1,
      product_name: 2,
      contributor: 3,
      product_type: 4,
      format: 5,
      supplier: 6,
      pub_date: 7,
      series: 8,
      bisac_category: 9,
      us_srp: 15,
      weight: 17
    }.freeze

    def self.call(path:)
      new(path: path).call
    end

    def initialize(path:)
      @path = path
    end

    def call
      sheet = open_sheet
      validate_headers!(sheet.row(1))

      rows = []
      (2..sheet.last_row).each do |row_number|
        raw = sheet.row(row_number)
        next if row_blank?(raw)

        rows << build_row(row_number, raw)
      end

      rows
    end

    private

    def open_sheet
      spreadsheet = ::Roo::Spreadsheet.open(@path, extension: extension_for(@path))
      spreadsheet.sheet(0)
    end

    def extension_for(path)
      ext = File.extname(path).delete_prefix(".").downcase
      ext = "xls" if ext.blank?
      ext.to_sym
    end

    def validate_headers!(header_row)
      missing = REQUIRED_HEADERS.reject { |header| header_row.include?(header) }
      return if missing.empty?

      raise ParseError, "Missing required columns: #{missing.join(', ')}"
    end

    def row_blank?(raw)
      raw.compact_blank.empty?
    end

    def build_row(row_number, raw)
      Row.new(
        row_number: row_number,
        product_code: cell(raw, :product_code),
        ean: cell(raw, :ean),
        product_name: cell(raw, :product_name),
        contributor: cell(raw, :contributor),
        product_type: cell(raw, :product_type),
        format: cell(raw, :format),
        supplier: cell(raw, :supplier),
        pub_date: parse_date(cell(raw, :pub_date)),
        series: cell(raw, :series),
        bisac_category: cell(raw, :bisac_category),
        us_srp_cents: parse_money_cents(cell(raw, :us_srp)),
        weight: parse_weight(cell(raw, :weight))
      )
    end

    def cell(raw, key)
      raw[HEADER_INDEX.fetch(key)]&.to_s&.strip.presence
    end

    def parse_money_cents(value)
      return nil if value.blank?

      cleaned = value.to_s.strip
      return nil if cleaned.match?(/\An\/a\z/i)

      amount = cleaned.gsub(/[^0-9.\-]/, "")
      return nil if amount.blank?

      (BigDecimal(amount) * 100).round.to_i
    end

    def parse_date(value)
      return nil if value.blank?

      case value
      when Date then value
      when Time, DateTime then value.to_date
      else
        Date.strptime(value.to_s.strip, "%m/%d/%Y")
      end
    rescue ArgumentError
      nil
    end

    def parse_weight(value)
      return nil if value.blank?

      BigDecimal(value.to_s.strip)
    rescue ArgumentError
      nil
    end
  end
end
