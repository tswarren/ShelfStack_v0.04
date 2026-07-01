# frozen_string_literal: true

class StockConsideration < ApplicationRecord
  STATUSES = %w[open reviewing converted_to_demand dismissed duplicate already_carried].freeze

  TERMINAL_STATUSES = %w[converted_to_demand dismissed duplicate already_carried].freeze

  belongs_to :store
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :created_by_user, class_name: "User"
  belongs_to :reviewed_by_user, class_name: "User", optional: true
  belongs_to :converted_by_user, class_name: "User", optional: true
  belongs_to :dismissed_by_user, class_name: "User", optional: true

  has_one :converted_demand_line,
    class_name: "DemandLine",
    foreign_key: :stock_consideration_id,
    dependent: :nullify,
    inverse_of: :stock_consideration

  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :open_queue, -> { where(status: %w[open reviewing]) }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end
end
