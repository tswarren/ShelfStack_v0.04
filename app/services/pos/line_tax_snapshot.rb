# frozen_string_literal: true

module Pos
  class LineTaxSnapshot
    def self.apply!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
      line.assign_attributes(
        tax_category: tax_category,
        store_tax_rate: store_tax_rate,
        tax_rate_bps: tax_rate_bps,
        tax_cents: tax_cents,
        tax_identifier_snapshot: store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: store_tax_rate&.short_name
      )
    end
  end
end
