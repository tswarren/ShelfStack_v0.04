# frozen_string_literal: true

class ProductBisacSync
  def self.sync!(product:, **kwargs)
    CatalogItemBisacSync.sync!(record: product, **kwargs)
  end
end
