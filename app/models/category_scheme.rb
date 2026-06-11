# frozen_string_literal: true

class CategoryScheme < ApplicationRecord
  PURPOSES = %w[store_sections_topics reporting website browse internal].freeze

  has_many :category_nodes, dependent: :restrict_with_error
  has_many :categorizations, through: :category_nodes

  validates :scheme_key, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :name, presence: true, uniqueness: true
  validates :purpose, presence: true, inclusion: { in: PURPOSES }

  scope :active_records, -> { where(active: true) }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.scheme_key = scheme_key&.strip&.downcase
    self.name = name&.strip
    self.purpose = purpose&.strip&.downcase
  end
end
