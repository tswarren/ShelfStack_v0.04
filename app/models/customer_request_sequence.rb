# frozen_string_literal: true

class CustomerRequestSequence < ApplicationRecord
  belongs_to :store

  validates :last_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
