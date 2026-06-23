# frozen_string_literal: true

class BuybackSequence < ApplicationRecord
  belongs_to :workstation

  validates :last_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
