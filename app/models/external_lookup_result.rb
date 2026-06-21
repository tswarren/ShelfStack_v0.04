# frozen_string_literal: true

class ExternalLookupResult < ApplicationRecord
  belongs_to :external_lookup_request
  belongs_to :local_catalog_item, class_name: "CatalogItem", optional: true
  belongs_to :local_product, class_name: "Product", optional: true
  belongs_to :local_product_variant, class_name: "ProductVariant", optional: true
  has_many :external_catalog_imports, dependent: :restrict_with_error

  validates :source_key, presence: true
end
