# frozen_string_literal: true

class PosVoid < ApplicationRecord
  belongs_to :pos_transaction
  belongs_to :store
  belongs_to :workstation
  belongs_to :pos_register_session
  belongs_to :voided_by_user, class_name: "User"
  belongs_to :pos_authorization, optional: true

  has_one :inventory_posting, as: :source, class_name: "InventoryPosting", dependent: :restrict_with_error

  validates :voided_at, presence: true
  validates :business_date, presence: true
end
