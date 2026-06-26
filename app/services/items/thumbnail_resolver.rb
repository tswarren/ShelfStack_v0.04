# frozen_string_literal: true

module Items
  class ThumbnailResolver
    Result = Data.define(:attachment, :source)

    def self.resolve(item:)
      new(item:).resolve
    end

    def initialize(item:)
      @item = item
    end

    def resolve
      if item.product&.cover_image&.attached?
        return Result.new(attachment: item.product.cover_image, source: :product)
      end

      if item.catalog_item&.primary_thumbnail&.attached?
        return Result.new(attachment: item.catalog_item.primary_thumbnail, source: :catalog)
      end

      Result.new(attachment: nil, source: :placeholder)
    end

    private

    attr_reader :item
  end
end
