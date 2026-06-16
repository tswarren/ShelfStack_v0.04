# frozen_string_literal: true

module Setup
  class CategoryNodesController < BaseController
    before_action :set_category_scheme
    before_action :set_category_node, only: %i[show edit update destroy inactivate reactivate]
    before_action -> { authorize!("setup.category_schemes.view") }, only: %i[index show]
    before_action -> { authorize!("setup.category_schemes.create") }, only: %i[new create]
    before_action -> { authorize!("setup.category_schemes.update") }, only: %i[edit update]
    before_action -> { authorize!("setup.category_schemes.inactivate") }, only: :inactivate
    before_action -> { authorize!("setup.category_schemes.reactivate") }, only: :reactivate
    before_action -> { authorize!("setup.category_schemes.delete") }, only: :destroy
    before_action :load_form_collections, only: %i[new create edit update]

    def index
      @category_node_rows = CategoryNode.ordered_tree_rows_for(@category_scheme)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@category_node).limit(50)
    end

    def new
      @category_node = @category_scheme.category_nodes.build(active: true, sort_order: 0)
    end

    def create
      @category_node = @category_scheme.category_nodes.build(category_node_params)
      if @category_node.save
        record_audit!("category_node.created", @category_node)
        redirect_to setup_category_scheme_category_node_path(@category_scheme, @category_node), notice: "Category node created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category_node.update(category_node_params)
        record_audit!("category_node.updated", @category_node)
        redirect_to setup_category_scheme_category_node_path(@category_scheme, @category_node), notice: "Category node updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @category_node.children.exists? || @category_node.categorizations.exists?
        redirect_to setup_category_scheme_category_node_path(@category_scheme, @category_node),
                    alert: "Category node cannot be deleted. Inactivate instead."
      else
        @category_node.destroy
        record_audit!("category_node.deleted", @category_node)
        redirect_to setup_category_scheme_category_nodes_path(@category_scheme), notice: "Category node deleted."
      end
    end

    def inactivate
      @category_node.inactivate!
      record_audit!("category_node.inactivated", @category_node)
      redirect_to setup_category_scheme_category_node_path(@category_scheme, @category_node), notice: "Category node inactivated."
    end

    def reactivate
      @category_node.reactivate!
      record_audit!("category_node.reactivated", @category_node)
      redirect_to setup_category_scheme_category_node_path(@category_scheme, @category_node), notice: "Category node reactivated."
    end

    private

    def set_category_scheme
      @category_scheme = CategoryScheme.find(params[:category_scheme_id])
    end

    def set_category_node
      @category_node = @category_scheme.category_nodes.find(params[:id])
    end

    def load_form_collections
      @parent_nodes = @category_scheme.category_nodes.active_records.where.not(id: @category_node&.id).order(:sort_order, :name).to_a
      @sub_departments = SubDepartment.active_records.order(:name)
      @display_locations = DisplayLocation.active_for_tree_select
      @store_category_nodes = if @category_scheme.scheme_key == Bisac::CategoryNodeImporter::SCHEME_KEY
                                store_scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
                                store_scheme ? CategoryNode.active_for_tree_select(store_scheme) : CategoryNode.none
                              else
                                CategoryNode.none
                              end
    end

    def category_node_params
      params.require(:category_node).permit(
        :node_key, :name, :parent_id, :sort_order, :active,
        :default_sub_department_id, :default_display_location_id, :default_store_category_id
      )
    end
  end
end
