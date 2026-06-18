# frozen_string_literal: true

module Phase5TestHelper
  def seed_phase5_reference_data!
    Seeds::Phase5Permissions.seed!
  end

  def grant_all_phase5_permissions!(user, store: nil)
    Seeds::Phase5Permissions::PERMISSIONS.each do |attrs|
      grant_permission!(user, attrs[:key], store: store)
    end
  end

  def create_purchase_order!(store:, vendor:, attrs: {}, lines: [])
    order = PurchaseOrder.create!({
      store: store,
      vendor: vendor,
      status: "draft"
    }.merge(attrs))

    lines.each do |line_attrs|
      order.purchase_order_lines.create!(line_attrs)
    end

    order
  end

  def create_receipt!(store:, vendor:, attrs: {}, lines: [])
    receipt = Receipt.create!({
      store: store,
      vendor: vendor,
      receipt_type: "direct",
      status: "draft"
    }.merge(attrs))

    lines.each do |line_attrs|
      receipt.receipt_lines.create!(line_attrs)
    end

    receipt
  end

  def create_return_to_vendor!(store:, vendor:, attrs: {}, lines: [])
    rtv = ReturnToVendor.create!({
      store: store,
      vendor: vendor,
      status: "draft"
    }.merge(attrs))

    lines.each do |line_attrs|
      rtv.return_to_vendor_lines.create!(line_attrs)
    end

    rtv
  end

  def create_purchase_order_line_attrs(variant:, vendor:, **attrs)
    {
      product_variant: variant,
      vendor: vendor,
      quantity_ordered: 1,
      quantity_received: 0,
      status: "open"
    }.merge(attrs)
  end

  def receive_inventory!(store:, vendor:, variant:, user:, quantity:, unit_cost_cents: 800)
    receipt = create_receipt!(
      store: store,
      vendor: vendor,
      lines: [
        {
          product_variant: variant,
          quantity_expected: 0,
          quantity_received: quantity,
          quantity_accepted: quantity,
          quantity_rejected: 0,
          unit_cost_cents: unit_cost_cents
        }
      ]
    )
    Purchasing::PostReceipt.call(receipt: receipt, posted_by_user: user)
    InventoryBalance.find_by!(store: store, product_variant: variant)
  end
end
