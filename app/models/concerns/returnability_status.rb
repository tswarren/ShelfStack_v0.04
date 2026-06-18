# frozen_string_literal: true

module ReturnabilityStatus
  extend ActiveSupport::Concern

  RETURNABILITY_STATUSES = %w[returnable non_returnable conditional unknown].freeze

  included do
    validates :returnability_status, inclusion: { in: RETURNABILITY_STATUSES }, allow_nil: true
  end
end
