# frozen_string_literal: true

module Pos
  class LineTaxSnapshot
    def self.apply!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
      apply_final!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
    end

    def self.apply_normal!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
      line.assign_attributes(
        normal_tax_category: tax_category,
        normal_store_tax_rate: store_tax_rate,
        normal_tax_rate_bps: tax_rate_bps,
        normal_tax_cents: tax_cents,
        normal_tax_identifier_snapshot: store_tax_rate&.tax_identifier,
        normal_store_tax_rate_short_name_snapshot: store_tax_rate&.short_name
      )
    end

    def self.apply_final!(line, tax_category:, store_tax_rate:, tax_rate_bps:, tax_cents:)
      line.assign_attributes(
        tax_category: tax_category,
        store_tax_rate: store_tax_rate,
        tax_rate_bps: tax_rate_bps,
        tax_cents: tax_cents,
        tax_identifier_snapshot: store_tax_rate&.tax_identifier,
        store_tax_rate_short_name_snapshot: store_tax_rate&.short_name
      )
    end

    def self.zero_normal!(line)
      line.assign_attributes(
        normal_tax_category: nil,
        normal_store_tax_rate: nil,
        normal_tax_rate_bps: nil,
        normal_tax_cents: 0,
        normal_tax_identifier_snapshot: nil,
        normal_store_tax_rate_short_name_snapshot: nil
      )
    end

    def self.zero_final!(line)
      line.assign_attributes(
        tax_category: nil,
        store_tax_rate: nil,
        tax_rate_bps: nil,
        tax_cents: 0,
        tax_identifier_snapshot: nil,
        store_tax_rate_short_name_snapshot: nil
      )
    end
  end
end
