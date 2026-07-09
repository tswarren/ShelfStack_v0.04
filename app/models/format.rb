# frozen_string_literal: true

class Format < ApplicationRecord
  has_many :catalog_items, dependent: :restrict_with_error

  validates :format_key, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :name, presence: true
  validates :short_name, presence: true, length: { maximum: 20 }
  validates :code, length: { maximum: 20 }, allow_blank: true
  validates :catalog_item_type, inclusion: { in: ProductMetadata::CATALOG_ITEM_TYPES }, allow_nil: true
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active_records, -> { where(active: true) }
  scope :ordered_for_display, -> { order(:sort_order, :format_key) }
  scope :eligible_for, lambda { |catalog_item_type:, digital: nil|
    scope = active_records.where(catalog_item_type: catalog_item_type)
    return scope if digital.nil?

    scope.where(digital: [ digital, nil ])
  }

  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def normalize_strings
    self.format_key = format_key&.strip&.downcase
    self.name = name&.strip
    self.short_name = short_name&.strip
    self.code = code&.strip.presence
  end
end
