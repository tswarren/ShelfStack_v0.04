# frozen_string_literal: true

module AddItem
  class ProductSkuGenerator
    PREFIX = "P"

    def self.generate!
      loop do
        sku = next_sku
        return sku unless Product.exists?(sku: sku)
      end
    end

    def self.next_sku
      latest = Product.where("sku LIKE ?", "#{PREFIX}%")
                      .order(sku: :desc)
                      .limit(1)
                      .pick(:sku)
      sequence = latest.to_s.delete_prefix(PREFIX).to_i + 1
      format("#{PREFIX}%08d", sequence)
    end
    private_class_method :next_sku
  end
end
