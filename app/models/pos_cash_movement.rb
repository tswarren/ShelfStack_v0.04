# frozen_string_literal: true

class PosCashMovement < ApplicationRecord
  MOVEMENT_TYPES = %w[paid_in paid_out].freeze

  belongs_to :pos_register_session
  belongs_to :store
  belongs_to :recorded_by_user, class_name: "User"

  validates :movement_type, presence: true, inclusion: { in: MOVEMENT_TYPES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :recorded_at, presence: true
end
