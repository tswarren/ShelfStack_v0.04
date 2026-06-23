# frozen_string_literal: true

class StoredValueIdentifier < ApplicationRecord
  IDENTIFIER_TYPES = %w[manual generated legacy_import].freeze

  belongs_to :stored_value_account
  belongs_to :replaced_by_identifier, class_name: "StoredValueIdentifier", optional: true
  has_one :replacement_of, class_name: "StoredValueIdentifier", foreign_key: :replaced_by_identifier_id,
          inverse_of: :replaced_by_identifier, dependent: :nullify

  validates :identifier_type, presence: true, inclusion: { in: IDENTIFIER_TYPES }
  validates :lookup_digest, presence: true, uniqueness: { conditions: -> { where(active: true) } }

  scope :active_records, -> { where(active: true) }

  def revealable?
    encrypted_value.present?
  end

  def inactivate!
    update!(active: false)
  end
end
