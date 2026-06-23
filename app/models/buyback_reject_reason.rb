# frozen_string_literal: true

class BuybackRejectReason < ApplicationRecord
  validates :reason_key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active_records, -> { where(active: true) }
end
