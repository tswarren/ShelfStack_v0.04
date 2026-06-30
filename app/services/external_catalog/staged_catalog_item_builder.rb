# frozen_string_literal: true

module ExternalCatalog
  class StagedCatalogItemBuilder
    def self.build(lookup_result:, format: nil)
      StagedProductBuilder.build(lookup_result:, format:)
    end
  end
end
