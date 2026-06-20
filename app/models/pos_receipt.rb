# frozen_string_literal: true

class PosReceipt < ApplicationRecord
  belongs_to :pos_transaction
  belongs_to :store

  validates :receipt_number, presence: true, uniqueness: true
  validates :issued_at, presence: true
  validates :reprint_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
