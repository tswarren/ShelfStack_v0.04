# frozen_string_literal: true

class ExternalCatalogImport < ApplicationRecord
  STATUSES = %w[applied failed skipped].freeze
  ACTION_TYPES = %w[
    create_catalog_item
    link_existing_catalog_item
    fill_blank_existing_catalog_item
    skip
  ].freeze

  belongs_to :external_lookup_result
  belongs_to :external_data_source
  belongs_to :imported_by_user, class_name: "User"
  belongs_to :catalog_item, optional: true
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }

  scope :applied_imports, -> { where(status: "applied") }
end
