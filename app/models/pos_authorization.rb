# frozen_string_literal: true

class PosAuthorization < ApplicationRecord
  AUTHORIZATION_TYPES = %w[
    discount_over_limit
    no_receipt_return
    cash_refund_over_threshold
    force_close_register
    inactive_sell
    void_transaction
    other
  ].freeze

  belongs_to :store
  belongs_to :pos_transaction, optional: true
  belongs_to :pos_register_session, optional: true
  belongs_to :requested_by_user, class_name: "User"
  belongs_to :granted_by_user, class_name: "User", optional: true

  validates :authorization_type, presence: true, inclusion: { in: AUTHORIZATION_TYPES }

  def granted?
    granted_at.present?
  end
end
