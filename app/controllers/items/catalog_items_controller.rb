# frozen_string_literal: true

module Items
  class CatalogItemsController < BaseController
    include CatalogItemBisacSyncable

    before_action :set_catalog_item, only: %i[
      show edit update destroy inactivate reactivate add_identifier new_identifier generate_local_identifier
      set_primary_identifier edit_identifier update_identifier destroy_identifier
    ]
    before_action -> { authorize!("items.catalog_items.view") }, only: %i[index show]
    before_action -> { authorize!("items.catalog_items.create") }, only: %i[new create]
    before_action -> { authorize!("items.catalog_items.update") }, only: %i[
      edit update add_identifier new_identifier generate_local_identifier set_primary_identifier
      edit_identifier update_identifier destroy_identifier
    ]
    before_action -> { authorize!("items.catalog_items.inactivate") }, only: :inactivate
    before_action -> { authorize!("items.catalog_items.reactivate") }, only: :reactivate
    before_action -> { authorize!("items.catalog_items.delete") }, only: :destroy

    def index
      @catalog_items = CatalogItem.includes(:format, :catalog_item_identifiers).order(:title)
    end

    def show
      @audit_events = AuditEvent.for_auditable(@catalog_item).limit(50)
      @identifiers = @catalog_item.catalog_item_identifiers.order(:identifier_type, :normalized_identifier)
    end

    def new
      @catalog_item = CatalogItem.new(active: true, publication_status: "active", catalog_item_type: "book")
      @formats = Format.active_records.order(:name)
      load_bisac_form_state(@catalog_item)
      load_store_category_collections
    end

    def create
      @catalog_item = CatalogItem.new(catalog_item_params)
      @formats = Format.active_records.order(:name)

      saved = false
      CatalogItem.transaction do
        unless @catalog_item.save
          raise ActiveRecord::Rollback
        end

        if identifier_value_param.present?
          CatalogIdentifierService.add_identifier!(
            catalog_item: @catalog_item,
            identifier_type: identifier_type_param,
            value: identifier_value_param,
            primary: true,
            actor: current_user
          )
        end

        unless @catalog_item.reload.primary_identifier
          @catalog_item.errors.add(:base, "must have at least one active identifier")
          raise ActiveRecord::Rollback
        end

        saved = true
      end

      if saved
        bisac_result = sync_catalog_item_bisac!(@catalog_item)
        store_category_result = sync_catalog_store_category!(@catalog_item)
        record_audit!("catalog_item.created", @catalog_item)
        apply_bisac_sync_notice!(bisac_result)
        apply_store_category_sync_notice!(store_category_result)
        apply_identifier_validation_notice!(@catalog_item)
        redirect_to items_catalog_item_path(@catalog_item), notice: "Catalog item created."
      else
        load_bisac_form_state(@catalog_item)
        load_store_category_collections
        render :new, status: :unprocessable_entity
      end
    rescue CatalogIdentifierService::IdentifierError => e
      @catalog_item.errors.add(:base, e.message)
      load_bisac_form_state(@catalog_item)
      load_store_category_collections
      render :new, status: :unprocessable_entity
    end

    def edit
      @formats = Format.active_records.order(:name)
      load_bisac_form_state(@catalog_item)
      load_store_category_collections
    end

    def update
      @formats = Format.active_records.order(:name)
      if @catalog_item.update(catalog_item_params)
        bisac_result = sync_catalog_item_bisac!(@catalog_item)
        store_category_result = sync_catalog_store_category!(@catalog_item)
        record_audit!("catalog_item.updated", @catalog_item)
        apply_bisac_sync_notice!(bisac_result)
        apply_store_category_sync_notice!(store_category_result)
        redirect_to item_return_path(@catalog_item, tab: "catalog"), notice: "Catalog item updated."
      else
        load_bisac_form_state(@catalog_item)
        load_store_category_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @catalog_item.products.exists?
        redirect_to item_return_path(@catalog_item, tab: "catalog"),
                    alert: "Catalog item cannot be deleted. Inactivate instead."
      else
        @catalog_item.destroy
        record_audit!("catalog_item.deleted", @catalog_item)
        redirect_to items_root_path, notice: "Catalog item deleted."
      end
    end

    def inactivate
      @catalog_item.inactivate!
      record_audit!("catalog_item.inactivated", @catalog_item)
      redirect_to item_return_path(@catalog_item, tab: "catalog"), notice: "Catalog item inactivated."
    end

    def reactivate
      @catalog_item.reactivate!
      record_audit!("catalog_item.reactivated", @catalog_item)
      redirect_to item_return_path(@catalog_item, tab: "catalog"), notice: "Catalog item reactivated."
    end

    def add_identifier
      identifier = CatalogIdentifierService.add_identifier!(
        catalog_item: @catalog_item,
        identifier_type: params.require(:identifier_type),
        value: params.require(:identifier_value),
        primary: params[:primary] == "1",
        actor: current_user
      )
      record_audit!("catalog_item_identifier.created", identifier)
      apply_identifier_validation_notice!(identifier)
      redirect_to identifier_return_path, notice: "Identifier added."
    rescue CatalogIdentifierService::IdentifierError, ActiveRecord::RecordInvalid => e
      redirect_to identifier_return_path, alert: e.message
    end

    def new_identifier
    end

    def generate_local_identifier
      identifier = CatalogIdentifierService.generate_local!(catalog_item: @catalog_item, actor: current_user)
      record_audit!("catalog_item_identifier.created", identifier)
      redirect_to item_return_path(@catalog_item, tab: "catalog"), notice: "Local identifier generated."
    end

    def set_primary_identifier
      identifier = @catalog_item.catalog_item_identifiers.find(params[:identifier_id])
      CatalogIdentifierService.set_primary!(identifier: identifier, actor: current_user)
      redirect_to item_return_path(@catalog_item, tab: "catalog"), notice: "Primary identifier updated."
    end

    def edit_identifier
      @identifier = @catalog_item.catalog_item_identifiers.find(params[:identifier_id])
    end

    def update_identifier
      @identifier = @catalog_item.catalog_item_identifiers.find(params[:identifier_id])
      CatalogIdentifierService.update_identifier!(
        identifier: @identifier,
        value: params.require(:identifier_value),
        actor: current_user
      )
      apply_identifier_validation_notice!(@identifier.reload)
      redirect_to identifier_return_path, notice: "Identifier updated."
    rescue CatalogIdentifierService::IdentifierError, ActiveRecord::RecordInvalid => e
      redirect_to identifier_return_path, alert: e.message
    end

    def destroy_identifier
      @identifier = @catalog_item.catalog_item_identifiers.find(params[:identifier_id])
      CatalogIdentifierService.remove_identifier!(identifier: @identifier, actor: current_user)
      redirect_to identifier_return_path, notice: "Identifier removed."
    rescue CatalogIdentifierService::IdentifierError => e
      redirect_to identifier_return_path, alert: e.message
    end

    private

    def set_catalog_item
      @catalog_item = CatalogItem.find(params[:id])
    end

    def catalog_item_params
      params.require(:catalog_item).permit(
        :catalog_item_type, :title, :creators, :publisher, :publication_date, :publication_status,
        :series_name, :series_enumeration, :format_id, :edition_statement, :language_code,
        :height, :width, :depth, :dimension_units, :weight, :weight_units, :page_count,
        :duration_minutes, :large_print, :bisac_subjects, :genres, :themes, :target_audiences,
        :access_restrictions, :publication_frequency, :description, :year, :digital, :active,
        :store_category_id
      )
    end

    def load_store_category_collections
      scheme = CategoryScheme.active_records.find_by(scheme_key: CategoryNode::STORE_CATEGORIES_SCHEME_KEY)
      @store_category_nodes = scheme ? CategoryNode.active_for_tree_select(scheme) : CategoryNode.none
    end

    def sync_catalog_store_category!(_catalog_item)
      CatalogItemStoreCategorySync.apply!(
        catalog_item: @catalog_item,
        store_category_id: params.dig(:catalog_item, :store_category_id),
        bisac_category_node_ids: params[:bisac_category_node_ids]
      )
    end

    def apply_store_category_sync_notice!(result)
      return if result.warnings.blank?

      flash.now[:alert] = [flash.now[:alert], result.warnings.join(" ")].compact.join(" ")
    end

    def identifier_type_param
      params.dig(:catalog_item, :initial_identifier_type).presence || "isbn13"
    end

    def identifier_value_param
      params.dig(:catalog_item, :initial_identifier_value).to_s.strip
    end

    def identifier_return_path
      item_return_path(@catalog_item, tab: "catalog")
    end
  end
end
