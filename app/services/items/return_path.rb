# frozen_string_literal: true

module Items
  class ReturnPath
    include Rails.application.routes.url_helpers

    def self.for(record:, return_to: nil, tab: nil, variant_id: nil, anchor: nil, from_tbo_filters: {},
               customer_request_match: {})
      new(
        record: record,
        return_to: return_to,
        tab: tab,
        variant_id: variant_id,
        anchor: anchor,
        from_tbo_filters: from_tbo_filters,
        customer_request_match: customer_request_match
      ).call
    end

    def initialize(record:, return_to: nil, tab: nil, variant_id: nil, anchor: nil, from_tbo_filters: {},
                   customer_request_match: {})
      @record = record
      @return_to = return_to.to_s
      @tab = tab
      @variant_id = variant_id
      @anchor = anchor
      @from_tbo_filters = from_tbo_filters.to_h.symbolize_keys
      @customer_request_match = customer_request_match.to_h.symbolize_keys
    end

    def call
      return from_customer_request_path if from_customer_request_flow?
      return from_tbo_path if from_tbo_flow?
      return legacy_path unless item_flow?

      item_tab_path
    end

    def item_flow?
      @return_to == "item"
    end

    def from_tbo_flow?
      @return_to == "from_tbo"
    end

    def from_customer_request_flow?
      @return_to == Customers::RequestMatchContext::RETURN_TO
    end

    private

    def from_customer_request_path
      context = Customers::RequestMatchContext.new(
        return_to: @return_to,
        customer_request_id: @customer_request_match[:customer_request_id],
        line_id: @customer_request_match[:line_id],
        store: nil
      )
      context.return_path || items_root_path
    end

    def from_tbo_path
      from_tbo_orders_purchase_orders_path(@from_tbo_filters.compact)
    end

    def item_tab_path
      presenter = presenter_for_record
      params = presenter.route_params.merge(tab: resolved_tab)
      params[:variant_id] = @variant_id if @variant_id.present?
      path = items_item_path(params)
      @anchor.present? ? "#{path}##{@anchor}" : path
    end

    def resolved_tab
      return @tab if @tab.present?

      case @record
      when CatalogItem, Product, ProductVariant then "item_setup"
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
