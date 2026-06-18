# frozen_string_literal: true

module Purchasing
  class BuildableTboLinesQuery
    Row = TboQueueRowBuilder::Row

    def self.call(store:, vendor: nil, sourced_only: false, department_id: nil, format_id: nil)
      TboQueueRowBuilder.call(
        store:,
        vendor:,
        sourced_only:,
        department_id:,
        format_id:
      )
    end
  end
end
