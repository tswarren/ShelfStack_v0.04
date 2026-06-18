# frozen_string_literal: true

module Seeds
  module Phase5Inventory
    module_function

    def seed!
      seed_demo_sourcing!
    end

    def seed_demo_sourcing!
      vendor = Vendor.active_records.find_by(name: "Ingram")
      return if vendor.blank?

      ProductVariant.active_records.includes(:product).limit(5).find_each do |variant|
        product = variant.product
        next if product.blank?

        ProductVendor.find_or_initialize_by(product: product, vendor: vendor).tap do |pv|
          pv.vendor_item_number ||= variant.sku
          pv.supplier_discount_bps ||= vendor.default_supplier_discount_bps || 4000
          pv.returnability_status ||= "returnable"
          pv.preferred = true
          pv.active = true
          pv.save!
        end

        ProductVariantVendor.find_or_initialize_by(product_variant: variant, vendor: vendor).tap do |pvv|
          pvv.vendor_item_number ||= variant.sku
          pvv.supplier_discount_bps ||= vendor.default_supplier_discount_bps || 4000
          pvv.active = true
          pvv.save!
        end
      end
    end
  end
end
