# frozen_string_literal: true

module Items
  class SearchController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }

    def index
      @query = params[:q].to_s.strip
      @results = ItemSearch.call(query: @query)
    end
  end
end
