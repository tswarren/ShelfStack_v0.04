# frozen_string_literal: true

class TaxRateLookup
  class Error < StandardError; end
  class MissingRateError < Error; end
  class AmbiguousRateError < Error; end

  def self.call(store:, tax_category:, date:)
    new(store: store, tax_category: tax_category, date: date).call
  end

  def initialize(store:, tax_category:, date:)
    @store = store
    @tax_category = tax_category
    @date = date.to_date
  end

  def call
    mappings = StoreTaxCategoryRate.active_records
                                   .where(store_id: store.id, tax_category_id: tax_category.id)
                                   .applicable_on(date)
                                   .includes(:store_tax_rate)

    case mappings.size
    when 0
      raise MissingRateError,
            "No applicable tax rate for store #{store.store_number}, tax category #{tax_category.name}, date #{date}"
    when 1
      mappings.first.store_tax_rate
    else
      raise AmbiguousRateError,
            "Ambiguous tax rate for store #{store.store_number}, tax category #{tax_category.name}, date #{date}"
    end
  end

  private

  attr_reader :store, :tax_category, :date
end
