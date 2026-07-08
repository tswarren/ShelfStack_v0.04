# frozen_string_literal: true

module Items
  class SubdepartmentDisplayResolver
    Result = Data.define(:sub_department, :source)

    def self.for(variant:, product: nil)
      new(variant:, product:).call
    end

    def self.name_for(variant:, product: nil)
      self.for(variant: variant, product: product).sub_department&.name
    end

    def initialize(variant:, product: nil)
      @variant = variant
      @product = product || variant&.product
    end

    def call
      if variant&.sub_department.present?
        return Result.new(sub_department: variant.sub_department, source: "variant")
      end

      if product&.default_sub_department.present?
        return Result.new(sub_department: product.default_sub_department, source: "product")
      end

      store_category = product&.store_category || product&.catalog_item&.store_category
      if store_category.present?
        defaults = StoreCategoryDefaults.for(store_category_node: store_category)
        if defaults.default_sub_department.present?
          return Result.new(sub_department: defaults.default_sub_department, source: "store_category")
        end
      end

      Result.new(sub_department: nil, source: "none")
    end

    private

    attr_reader :variant, :product
  end
end
