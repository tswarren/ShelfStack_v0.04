# frozen_string_literal: true

module IngramCatalogImport
  class ProductTypeMapper
    class ProductTypeError < StandardError; end

    TYPE_MAP = {
      "book" => "book",
      "periodical" => "periodical",
      "magazine" => "periodical",
      "recorded music" => "recorded_music",
      "music" => "recorded_music",
      "videorecording" => "videorecording",
      "video" => "videorecording",
      "dvd" => "videorecording",
      "audiobook" => "audiobook",
      "ebook" => "ebook",
      "calendar" => "calendar",
      "map" => "map",
      "game" => "game",
      "gift" => "gift",
      "sideline" => "sideline",
      "other" => "other"
    }.freeze

    def self.resolve!(product_type)
      new(product_type).resolve!
    end

    def initialize(product_type)
      @product_type = product_type.to_s.strip
    end

    def resolve!
      raise ProductTypeError, "Product Type is required" if @product_type.blank?

      catalog_item_type = TYPE_MAP[normalized_type]
      raise ProductTypeError, "Unmapped Ingram product type: #{@product_type}" if catalog_item_type.blank?

      catalog_item_type
    end

    private

    def normalized_type
      @product_type.downcase.squeeze(" ")
    end
  end
end
