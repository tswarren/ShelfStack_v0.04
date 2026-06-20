# frozen_string_literal: true

module ExternalCatalog
  module Provider
    class IsbndbNormalizer
      def self.call(payload:, source_key: "isbndb")
        new(payload:, source_key:).call
      end

      def initialize(payload:, source_key: "isbndb")
        @payload = payload
        @source_key = source_key
      end

      def call
        book = @payload.is_a?(Hash) ? (@payload["book"] || @payload) : {}
        isbn13 = normalize_isbn(book["isbn13"].presence || book["isbn"])
        isbn10 = normalize_isbn(book["isbn10"])

        BookCandidate.new(
          source_key: @source_key,
          external_identifier: isbn13.presence || isbn10,
          isbn10: isbn10,
          isbn13: isbn13,
          title: book["title"].to_s.strip.presence,
          subtitle: extract_subtitle(book),
          authors: Array(book["authors"]).map(&:to_s).map(&:strip).reject(&:blank?),
          publisher: book["publisher"].to_s.strip.presence,
          date_published: book["date_published"].to_s.strip.presence,
          binding: book["binding"].to_s.strip.presence,
          language: book["language"].to_s.strip.presence,
          pages: book["pages"].to_i.positive? ? book["pages"].to_i : nil,
          msrp_cents: parse_msrp_cents(book["msrp"]),
          currency_code: "USD",
          image_url: book["image_original"].presence || book["image"].presence || book["image_url"].presence,
          synopsis: plain_text(book["synopsis"]),
          excerpt: plain_text(book["excerpt"]),
          subjects: Array(book["subjects"]).map(&:to_s).map(&:strip).reject(&:blank?),
          dewey_decimal: book["dewey_decimal"].to_s.strip.presence,
          dimensions: extract_dimensions(book),
          other_isbns: Array(book["other_isbns"]).map(&:to_s).reject(&:blank?),
          raw_payload: @payload
        )
      end

      private

      def normalize_isbn(value)
        return nil if value.blank?

        CatalogIdentifierService.normalize_preview("isbn13", value)
      rescue CatalogIdentifierService::IdentifierError
        nil
      end

      def extract_subtitle(book)
        title_long = book["title_long"].to_s.strip
        title = book["title"].to_s.strip
        return nil if title_long.blank? || title_long == title

        remainder = title_long.sub(/\A#{Regexp.escape(title)}/, "").strip
        remainder = remainder.sub(/\A[:,-]\s*/, "").strip
        remainder.presence
      end

      def parse_msrp_cents(value)
        return nil if value.blank?

        (value.to_d * 100).round
      end

      def extract_dimensions(book)
        {
          "dimensions" => book["dimensions"],
          "dimensions_structured" => book["dimensions_structured"]
        }.merge(extract_physical_dimensions(book)).merge(extract_weight(book)).compact
      end

      def extract_physical_dimensions(book)
        structured = book["dimensions_structured"]
        return {} unless structured.is_a?(Hash)

        book_height = structured_dimension(structured, "height")
        cover_width = structured_dimension(structured, "length")
        spine_depth = structured_dimension(structured, "width")

        dimensions = {
          "height" => book_height&.fetch(:value),
          "width" => cover_width&.fetch(:value),
          "depth" => spine_depth&.fetch(:value)
        }.compact

        unit = (book_height || cover_width || spine_depth)&.fetch(:unit)
        dimensions["dimension_units"] = unit if unit.present?
        dimensions
      end

      def structured_dimension(structured, key)
        raw = structured[key] || structured[key.to_sym]
        return nil unless raw.is_a?(Hash)

        value = raw["value"] || raw[:value]
        unit = raw["unit"] || raw[:unit]
        return nil if value.blank?

        target_unit, converted = convert_dimension(value.to_d, unit)
        return nil if target_unit.blank?

        { value: converted.round(2), unit: target_unit }
      end

      def convert_dimension(value, unit)
        case unit.to_s.downcase.strip
        when "mm", "millimeter", "millimeters"
          [ "cm", value / 10 ]
        when "cm", "centimeter", "centimeters"
          [ "cm", value ]
        when "m", "meter", "meters"
          [ "cm", value * 100 ]
        when "in", "inch", "inches", "\""
          [ "in", value ]
        else
          [ nil, nil ]
        end
      end

      def extract_weight(book)
        structured = book["dimensions_structured"]
        return {} unless structured.is_a?(Hash)

        weight = structured["weight"] || structured[:weight]
        return {} unless weight.is_a?(Hash)

        value = weight["value"] || weight[:value]
        unit = weight["unit"] || weight[:unit]
        return {} if value.blank?

        normalized_unit = normalize_weight_unit(unit)
        return {} if normalized_unit.blank?

        {
          "weight" => value.to_d.round(2),
          "weight_units" => normalized_unit
        }
      end

      def normalize_weight_unit(unit)
        case unit.to_s.downcase.strip
        when "pound", "pounds", "lbs", "lb" then "lb"
        when "ounce", "ounces", "oz" then "oz"
        when "kilogram", "kilograms", "kg" then "kg"
        when "gram", "grams", "g" then "g"
        end
      end

      def plain_text(value)
        HtmlToPlainText.call(value)
      end
    end
  end
end
