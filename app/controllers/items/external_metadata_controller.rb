# frozen_string_literal: true

module Items
  class ExternalMetadataController < BaseController
    before_action :load_catalog_item
    before_action :load_import

    def show
      authorize!("items.external_lookup.access")
      @lookup_result = @import.external_lookup_result
      @can_view_raw_payload = Authorization.allowed?(
        user: current_user,
        permission_key: "items.external_lookup.view_raw_payload",
        store: current_store
      )
    end

    private

    def load_catalog_item
      @catalog_item = CatalogItem.find(params[:catalog_item_id])
    end

    def load_import
      @import = @catalog_item.latest_external_catalog_import
      return if @import.present?

      redirect_to item_setup_return_path,
                  alert: "No external catalog metadata is linked to this item."
    end

    def item_setup_return_path
      product = @catalog_item.products.active_records.order(:id).first
      if product.present?
        items_item_path(product_id: product.id, tab: "item_setup")
      else
        items_item_path(catalog_item_id: @catalog_item.id, tab: "item_setup")
      end
    end
  end
end
