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

      Result.new(attachment: nil, source: :placeholder)
    end

    private

    attr_reader :item
  end
end
