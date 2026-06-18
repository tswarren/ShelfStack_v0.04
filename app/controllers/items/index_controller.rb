# frozen_string_literal: true

module Items
  class IndexController < BaseController
    INDEX_PARAMS = %i[q page format_id department_id sub_department_id store_category_id include_inactive].freeze

    def index
      load_filter_collections
      @query = index_params[:q].to_s.strip
      @include_inactive = ActiveModel::Type::Boolean.new.cast(index_params[:include_inactive])

      result = Items::IndexQuery.call(
        query: @query,
        format_id: index_params[:format_id],
        department_id: index_params[:department_id],
        sub_department_id: index_params[:sub_department_id],
        store_category_id: index_params[:store_category_id],
        include_inactive: @include_inactive,
        page: index_params[:page],
        per_page: Items::IndexQuery::DEFAULT_PER_PAGE
      )

      @results = result.results
      @total_count = result.total_count
      @page = result.page
      @per_page = result.per_page
      @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
      @operational_summaries = load_operational_summaries
    end

    private

    def index_params
      params.permit(*INDEX_PARAMS)
    end

    def load_operational_summaries
      return {} unless current_store.present?
      return {} unless inventory_signals_visible?

      Items::IndexOperationalSummary.for(
        store: current_store,
        user: current_user,
        results: @results
      )
    end

    def inventory_signals_visible?
      Authorization.allowed?(user: current_user, permission_key: "inventory.access", store: current_store) &&
        Authorization.allowed?(user: current_user, permission_key: "inventory.balances.view", store: current_store)
    end

    def load_filter_collections
      @formats = Format.active_records.order(:name)
      @departments = Department.active_records.order(:department_number)
      @sub_departments = if index_params[:department_id].present?
                           SubDepartment.active_records.where(department_id: index_params[:department_id]).order(:name)
      else
                           SubDepartment.active_records.order(:name)
      end
      @store_category_scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      @store_category_nodes = if @store_category_scheme
                                CategoryNode.active_for_tree_select(@store_category_scheme)
      else
                                CategoryNode.none
      end
    end
  end
end
