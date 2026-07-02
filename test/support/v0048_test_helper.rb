# frozen_string_literal: true

module V0048TestHelper
  def seed_v0048_permissions!
    Seeds::V0046Permissions.seed!
    Seeds::V0047Permissions.seed!
    Seeds::V0048Permissions.seed!
  end

  def grant_v0048_sourcing_permissions!(user, store: nil)
    %w[
      sourcing.access
      sourcing.runs.create
      sourcing.attempts.create
      sourcing.attempts.submit
      sourcing.responses.record
      sourcing.attempts.cascade
      sourcing.attempts.cancel
      sourcing.runs.close
      sourcing.vendor_override
    ].each do |key|
      grant_permission!(user, key, store: store)
    end
  end

  def create_special_order_demand!(store:, actor:, variant:, quantity: 1, **attrs)
    customer = attrs.delete(:customer) || create_customer!(display_name: "Sourcing Customer")
    DemandLines::Create.call!(
      store: store,
      actor: actor,
      capture_intent: "special_order",
      variant: variant,
      customer: customer,
      quantity: quantity,
      **attrs
    )
  end

  def create_vendor_for_variant!(variant, attrs = {})
    vendor_item_number = attrs.delete(:vendor_item_number) || "VIN-#{SecureRandom.hex(3)}"
    vendor = create_vendor!(**attrs)
    ProductVariantVendor.create!(
      product_variant: variant,
      vendor: vendor,
      vendor_item_number: vendor_item_number,
      active: true
    )
    vendor
  end
end
