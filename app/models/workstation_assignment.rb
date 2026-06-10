# frozen_string_literal: true

class WorkstationAssignment < ApplicationRecord
  belongs_to :workstation
  belongs_to :assigned_by_user, class_name: "User", optional: true

  validates :assignment_token_digest, presence: true, uniqueness: true
  validates :assigned_at, presence: true

  scope :active_records, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_seen!
    update!(last_seen_at: Time.current)
  end
end
