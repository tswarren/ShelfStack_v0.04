# frozen_string_literal: true

module Purchasing
  class BuildableTboLinesQuery
    Row = Data.define(:line, :sourcing)

    def self.call(store:, vendor: nil, sourced_only: false)
      new(store:, vendor:, sourced_only:).call
    end

    def initialize(store:, vendor: nil, sourced_only: false)
      @store = store
      @vendor = vendor
      @sourced_only = sourced_only
    end

    def call
      return [] if store.blank?

      rows = buildable_lines.map do |line|
        sourcing = vendor.present? ? SourcingLookup.for(variant: line.product_variant, vendor: vendor) : nil
        Row.new(line:, sourcing:)
      end

      rows = rows.select { |row| row.sourcing&.sourcing_record_present } if sourced_only && vendor.present?
      rows
    end

    private

    attr_reader :store, :vendor, :sourced_only

    def buildable_lines
      PurchaseRequestLine
        .buildable_for_store(store)
        .includes(:product_variant, purchase_request: :store)
        .order("purchase_requests.created_at DESC, purchase_request_lines.line_number ASC")
    end
  end
end
