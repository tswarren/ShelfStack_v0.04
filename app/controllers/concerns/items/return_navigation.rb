# frozen_string_literal: true

module Items
  module ReturnNavigation
    extend ActiveSupport::Concern

    private

    def item_flow?
      params[:return_to].to_s == "item"
    end

    def item_return_path(record, tab: nil, variant_id: nil)
      Items::ReturnPath.for(
        record: record,
        return_to: params[:return_to],
        tab: tab,
        variant_id: variant_id
      )
    end
  end
end
