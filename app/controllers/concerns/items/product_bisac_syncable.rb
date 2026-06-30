# frozen_string_literal: true

module Items
  module ProductBisacSyncable
    extend ActiveSupport::Concern

    private

    def load_bisac_form_state(product)
      @bisac_scheme_loaded = CategoryScheme.active_records.exists?(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)

      if bisac_structured_input?
        load_bisac_form_state_from_params
      elsif product.persisted?
        load_bisac_form_state_from_product(product)
      else
        clear_bisac_form_state
      end
    end

    def load_bisac_form_state_from_product(product)
      primary = product.primary_bisac_categorization
      @primary_bisac_category_node_id = primary&.category_node_id
      @primary_bisac_category_node_label = bisac_node_label(primary&.category_node)
      @bisac_category_node_ids = product.bisac_categorizations
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

    def sync_product_bisac!(product)
      ProductBisacSync.sync!(
        product: product,
        primary_bisac_category_node_id: params[:primary_bisac_category_node_id],
        bisac_category_node_ids: params[:bisac_category_node_ids],
        bisac_subjects: product_metadata_params_source.dig(:bisac_subjects),
        structured: bisac_structured_input?,
        source: bisac_sync_source
      )
    end

    def apply_bisac_sync_notice!(result)
      return if result.skipped || result.warnings.blank?

      notice = flash[:notice].presence
      warning_text = result.warnings.join(" ")
      flash[:notice] = [ notice, warning_text ].compact.join(" ")
    end

    def apply_transitional_identifier_notice!(validation_message)
      return if validation_message.blank?

      message = "Identifier saved with warning: #{validation_message}"
      flash[:warning] = [ flash[:warning], message ].compact.join(" ")
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

    def product_metadata_params_source
      params[:product].presence || params[:catalog_item].presence || {}
    end
  end
end
