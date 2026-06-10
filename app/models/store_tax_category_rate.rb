# frozen_string_literal: true

class StoreTaxCategoryRate < ApplicationRecord
  OPEN_ENDED_END_DATE = Date.new(9999, 12, 31)

  belongs_to :store
  belongs_to :tax_category
  belongs_to :store_tax_rate

  validates :effective_on, presence: true
  validate :ends_on_not_before_effective_on
  validate :store_tax_rate_belongs_to_same_store
  validate :no_overlapping_active_mappings

  scope :active_records, -> { where(active: true) }

  scope :applicable_on, lambda { |date|
    where("effective_on <= ?", date)
      .where("ends_on IS NULL OR ends_on >= ?", date)
  }

  scope :overlapping_with, lambda { |mapping|
    other_end = mapping.ends_on || OPEN_ENDED_END_DATE
    other_start = mapping.effective_on

    where(store_id: mapping.store_id, tax_category_id: mapping.tax_category_id)
      .where.not(id: mapping.id)
      .where("effective_on <= ? AND COALESCE(ends_on, ?) >= ?", other_end, OPEN_ENDED_END_DATE, other_start)
  }

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  private

  def ends_on_not_before_effective_on
    return if ends_on.blank? || effective_on.blank?

    errors.add(:ends_on, "must be on or after effective date") if ends_on < effective_on
  end

  def store_tax_rate_belongs_to_same_store
    return if store_tax_rate.blank? || store_id.blank?

    errors.add(:store_tax_rate, "must belong to the same store") if store_tax_rate.store_id != store_id
  end

  def no_overlapping_active_mappings
    return unless active?
    return if store_id.blank? || tax_category_id.blank? || effective_on.blank?

    if self.class.active_records.overlapping_with(self).exists?
      errors.add(:base, "overlaps with another active mapping for this store and tax category")
    end
  end
end
