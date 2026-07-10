# frozen_string_literal: true

module Items
  class GenreSubjectSearchesController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }

    ALLOWED_SCHEMES = CategoryScheme::GENRE_PURPOSES.freeze

    def index
      scheme_key = params[:scheme].to_s
      query = params[:q].to_s.strip

      unless ALLOWED_SCHEMES.include?(scheme_key)
        render json: { results: [] }
        return
      end

      scheme = CategoryScheme.active_records.find_by(scheme_key: scheme_key)
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
            node_key: node.node_key,
            name: node.name,
            breadcrumb_label: node.breadcrumb_label
          }
        end
      }
    end
  end
end
