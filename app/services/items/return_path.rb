# frozen_string_literal: true

module Items
  class ReturnPath
    include Rails.application.routes.url_helpers

    def self.for(record:, return_to: nil, tab: nil, variant_id: nil)
      new(record: record, return_to: return_to, tab: tab, variant_id: variant_id).call
    end

    def initialize(record:, return_to: nil, tab: nil, variant_id: nil)
      @record = record
      @return_to = return_to.to_s
      @tab = tab
      @variant_id = variant_id
    end

    def call
      return legacy_path unless item_flow?

      item_tab_path
    end

    def item_flow?
      @return_to == "item"
    end

    private

    def item_tab_path
      presenter = presenter_for_record
      params = presenter.route_params.merge(tab: resolved_tab)
      params[:variant_id] = @variant_id if @variant_id.present?
      items_item_path(params)
    end

    def resolved_tab
      return @tab if @tab.present?

      case @record
      when CatalogItem then "catalog"
      when Product, ProductVariant then "selling"
      else "overview"
      end
    end

    def presenter_for_record
      case @record
      when CatalogItem
        ItemPresenter.from_catalog_item(@record)
      when Product
        ItemPresenter.from_product(@record)
      when ProductVariant
        ItemPresenter.from_product_variant(@record)
      else
        raise ArgumentError, "Unsupported record type: #{@record.class.name}"
      end
    end

    def legacy_path
      case @record
      when CatalogItem
        items_catalog_item_path(@record)
      when Product
        items_product_path(@record)
      when ProductVariant
        items_product_variant_path(@record)
      else
        raise ArgumentError, "Unsupported record type: #{@record.class.name}"
      end
    end
  end
end
