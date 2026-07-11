# frozen_string_literal: true

module ProductMetadata
  extend ActiveSupport::Concern

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

  included do
    belongs_to :format, optional: true
    belongs_to :store_category, class_name: "CategoryNode", optional: true
    has_many :categorizations, as: :categorizable, dependent: :destroy

    validates :catalog_item_type, inclusion: { in: CATALOG_ITEM_TYPES }, allow_blank: true
    validates :publication_status, presence: true, inclusion: { in: PUBLICATION_STATUSES }
    validates :publication_frequency, inclusion: { in: PUBLICATION_FREQUENCIES }, allow_blank: true
    validates :dimension_units, inclusion: { in: DIMENSION_UNITS }, allow_blank: true
    validates :weight_units, inclusion: { in: WEIGHT_UNITS }, allow_blank: true
    validates :year, format: { with: /\A[0-9]{4}\z/ }, allow_blank: true

    validate :format_must_be_active, if: -> { format_id.present? }
    validate :store_category_must_be_valid, if: -> { store_category_id.present? }
    validate :metadata_title_required_for_product_first_records, on: :create

    before_validation :parse_metadata_fields
    before_validation :normalize_metadata_strings
  end

  def display_title
    title.presence || name
  end

  def bibliographic?
    catalog_item_type.in?(%w[book audiobook ebook periodical recorded_music videorecording map game calendar])
  end

  def bisac_categorizations
    categorizations
      .joins(category_node: :category_scheme)
      .where(category_schemes: { scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY })
      .includes(category_node: :parent)
  end

  def genre_categorizations
    categorizations
      .joins(category_node: :category_scheme)
      .where(category_schemes: { purpose: CategoryScheme::GENRE_PURPOSES })
      .includes(category_node: :parent)
  end

  def primary_bisac_categorization
    bisac_categorizations.primary_records.first
  end

  def metadata_fused?
    title.present?
  end

  private

  def normalize_metadata_strings
    self.title = title&.strip.presence
    self.subtitle = subtitle&.strip.presence
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

  def store_category_must_be_valid
    return if store_category.blank?

    unless store_category.store_category?
      errors.add(:store_category, "must belong to the store categories scheme")
    end
    return if store_category.active?

    errors.add(:store_category, "must be active")
  end

  def metadata_title_required_for_product_first_records
    return if catalog_item_id.present?
    return if title.present? || name.present?

    errors.add(:title, "can't be blank")
  end
end
