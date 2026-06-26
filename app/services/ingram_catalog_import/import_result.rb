# frozen_string_literal: true

module IngramCatalogImport
  class ImportResult
    RowOutcome = Struct.new(
      :row_number,
      :identifier,
      :title,
      :status,
      :message,
      :catalog_item_id,
      :product_id,
      :product_variant_id,
      keyword_init: true
    )

    attr_reader :outcomes, :preferred_vendor_assignments, :preferred_vendor_skipped

    def initialize
      @outcomes = []
      @counts = Hash.new(0)
      @preferred_vendor_assignments = 0
      @preferred_vendor_skipped = 0
    end

    def add_outcome(outcome)
      @outcomes << outcome
      @counts[outcome.status] += 1
    end

    def count(status)
      @counts[status]
    end

    def total_rows
      @outcomes.size
    end

    def summary
      {
        "total_rows" => total_rows,
        "catalog_created" => count(:catalog_created),
        "catalog_updated" => count(:catalog_updated),
        "product_created" => count(:product_created),
        "product_updated" => count(:product_updated),
        "variant_created" => count(:variant_created),
        "variant_matched" => count(:variant_matched),
        "skipped" => count(:skipped),
        "error" => count(:error),
        "preferred_vendor_assignments" => preferred_vendor_assignments,
        "preferred_vendor_skipped" => preferred_vendor_skipped
      }
    end
  end
end
