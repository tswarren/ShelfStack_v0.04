# frozen_string_literal: true

class CatalogItem < ApplicationRecord
  CATALOG_ITEM_TYPES = %w[
    book calendar periodical recorded_music sideline videorecording
    audiobook ebook map game gift other
  ].freeze

  PUBLICATION_STATUSES = %w[
    active not_yet_published out_of_print out_of_stock_indefinitely
    discontinued publication_cancelled unknown
  ].freeze

  PUBLICATION_FREQUENCIES = %w[
    daily weekly biweekly semi_monthly monthly bi_monthly quarterly
    semi_annual annual irregular unknown
  ].freeze

  DIMENSION_UNITS = %w[cm in].freeze
  WEIGHT_UNITS = %w[g kg lb oz].freeze

  belongs_to :format
  has_many :catalog_item_identifiers, dependent: :destroy
  has_many :products, dependent: :restrict_with_error

  accepts_nested_attributes_for :catalog_item_identifiers, allow_destroy: true, reject_if: :all_blank

  validates :catalog_item_type, presence: true, inclusion: { in: CATALOG_ITEM_TYPES }
  validates :title, presence: true
  validates :publication_status, presence: true, inclusion: { in: PUBLICATION_STATUSES }
  validates :publication_frequency, inclusion: { in: PUBLICATION_FREQUENCIES }, allow_blank: true
  validates :dimension_units, inclusion: { in: DIMENSION_UNITS }, allow_blank: true
  validates :weight_units, inclusion: { in: WEIGHT_UNITS }, allow_blank: true
  validates :year, format: { with: /\A[0-9]{4}\z/ }, allow_blank: true
  validate :format_must_be_active
  validate :must_have_active_primary_identifier, on: :update

  scope :active_records, -> { where(active: true) }

  before_validation :parse_metadata_fields
  before_validation :normalize_strings

  def inactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end

  def primary_identifier
    catalog_item_identifiers.active_records.find_by(primary_identifier: true)
  end

  def active_identifiers
    catalog_item_identifiers.active_records
  end

  private

  def normalize_strings
    self.title = title&.strip
    self.publisher = publisher&.strip.presence
    self.series_name = series_name&.strip.presence
    self.series_enumeration = series_enumeration&.strip.presence
    self.edition_statement = edition_statement&.strip.presence
    self.language_code = language_code&.strip.presence
    self.year = year&.strip.presence
  end

  def parse_metadata_fields
    if will_save_change_to_creators?
      self.creator_details = MetadataParser.parse_creators(creators)
    end

    if will_save_change_to_bisac_subjects?
      self.bisac_subject_data = MetadataParser.parse_subjects(bisac_subjects)
    end

    if will_save_change_to_genres?
      self.genre_data = MetadataParser.parse_subjects(genres)
    end

    if will_save_change_to_themes?
      self.theme_data = MetadataParser.parse_subjects(themes)
    end

    if will_save_change_to_target_audiences?
      self.target_audience_data = MetadataParser.parse_subjects(target_audiences)
    end

    if will_save_change_to_access_restrictions?
      self.access_restriction_data = MetadataParser.parse_subjects(access_restrictions)
    end
  end

  def format_must_be_active
    return if format.blank? || format.active?

    errors.add(:format, "must be active")
  end

  def must_have_active_primary_identifier
    return if catalog_item_identifiers.active_records.exists?(primary_identifier: true)

    errors.add(:base, "must have exactly one active primary identifier")
  end
end
