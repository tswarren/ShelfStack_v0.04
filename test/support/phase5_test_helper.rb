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
end
