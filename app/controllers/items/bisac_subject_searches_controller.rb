# frozen_string_literal: true

module Items
  class BisacSubjectSearchesController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }

    def index
      scheme = CategoryScheme.active_records.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
      query = params[:q].to_s.strip

      if scheme.blank? || query.blank?
        render json: { results: [] }
        return
      end

      nodes = scheme.category_nodes.active_records
                    .includes(:parent)
                    .matching_name_or_key(query)
                    .order(:name)
                    .limit(25)

      render json: {
        results: nodes.map do |node|
          {
            id: node.id,
            node_key: node.node_key.upcase,
            name: node.name,
            breadcrumb_label: node.breadcrumb_label
          }
        end
      }
    end
  end
end
