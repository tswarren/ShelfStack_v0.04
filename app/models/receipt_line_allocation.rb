# frozen_string_literal: true

class ReceiptLineAllocation < ApplicationRecord
  belongs_to :receipt_line
  belongs_to :purchase_order_line_allocation, optional: true
  belongs_to :inventory_reservation, optional: true
  belongs_to :customer_request_line, optional: true
  belongs_to :special_order, optional: true

  validates :quantity_allocated, numericality: { only_integer: true, greater_than: 0 }
end
