# frozen_string_literal: true

module Items
  module CatalogItemBisacSyncable
    extend ActiveSupport::Concern

    private

    def load_bisac_form_state(catalog_item)
      @bisac_scheme_loaded = CategoryScheme.active_records.exists?(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)

      if bisac_structured_input?
        load_bisac_form_state_from_params
      elsif catalog_item.persisted?
        load_bisac_form_state_from_catalog_item(catalog_item)
      else
        clear_bisac_form_state
      end
    end

    def load_bisac_form_state_from_catalog_item(catalog_item)
      primary = catalog_item.primary_bisac_categorization
      @primary_bisac_category_node_id = primary&.category_node_id
      @primary_bisac_category_node_label = bisac_node_label(primary&.category_node)
      @bisac_category_node_ids = catalog_item.bisac_categorizations
                                             .where.not(id: primary&.id)
                                             .map { |categorization| bisac_selection_entry(categorization.category_node) }
    end

    def load_bisac_form_state_from_params
      @primary_bisac_category_node_id = params[:primary_bisac_category_node_id].presence
      @primary_bisac_category_node_label = bisac_node_label(find_bisac_node(@primary_bisac_category_node_id))
      @bisac_category_node_ids = Array(params[:bisac_category_node_ids]).filter_map do |node_id|
        node = find_bisac_node(node_id)
        bisac_selection_entry(node) if node
      end
    end

    def clear_bisac_form_state
      @primary_bisac_category_node_id = nil
      @primary_bisac_category_node_label = nil
      @bisac_category_node_ids = []
    end

    def sync_catalog_item_bisac!(catalog_item)
      result = CatalogItemBisacSync.sync!(
        catalog_item: catalog_item,
        primary_bisac_category_node_id: params[:primary_bisac_category_node_id],
        bisac_category_node_ids: params[:bisac_category_node_ids],
        bisac_subjects: params.dig(:catalog_item, :bisac_subjects),
        structured: bisac_structured_input?,
        source: bisac_sync_source
      )
      result
    end

    def apply_bisac_sync_notice!(result)
      return if result.skipped || result.warnings.blank?

      notice = flash[:notice].presence
      warning_text = result.warnings.join(" ")
      flash[:notice] = [notice, warning_text].compact.join(" ")
    end

    def apply_identifier_validation_notice!(record)
      identifier = if record.is_a?(CatalogItemIdentifier)
                       record
                     else
                       record.reload.primary_identifier
                     end
      return if identifier.blank? || identifier.validation_message.blank?

      message = "Identifier saved with warning: #{identifier.validation_message}"
      flash[:warning] = [flash[:warning], message].compact.join(" ")
    end

    def bisac_structured_input?
      params.key?(:primary_bisac_category_node_id) || params.key?(:bisac_category_node_ids)
    end

    def bisac_sync_source
      "manual"
    end

    def find_bisac_node(node_id)
      return if node_id.blank?

      CategoryNode.active_records
                  .joins(:category_scheme)
                  .find_by(id: node_id, category_schemes: { scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY })
    end

    def bisac_node_label(node)
      return if node.blank?

      "#{node.breadcrumb_label} (#{node.node_key.upcase})"
    end

    def bisac_selection_entry(node)
      {
        id: node.id,
        label: bisac_node_label(node)
      }
    end
  end
end
