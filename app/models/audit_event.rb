# frozen_string_literal: true

class AuditEvent < ApplicationRecord
  belongs_to :actor_user, class_name: "User"
  belongs_to :auditable, polymorphic: true, optional: true
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :store, optional: true
  belongs_to :workstation, optional: true
  belongs_to :user_session, optional: true

  validates :event_name, :occurred_at, presence: true
  validate :event_details_must_be_hash

  before_update :prevent_modification

  scope :recent_first, -> { order(occurred_at: :desc) }

  def self.for_auditable(record)
    where(auditable: record).recent_first
  end

  private

  def event_details_must_be_hash
    errors.add(:event_details, "must be a hash") unless event_details.is_a?(Hash)
  end

  def prevent_modification
    raise ActiveRecord::ReadOnlyRecord, "Audit events are append-only"
  end
end
