# frozen_string_literal: true

module Items
  class ProductEntryContextsController < BaseController
    include ProductEntryContextable

    def show
      authorize!("items.access")
      product = find_product_for_context
      entry_context = build_product_entry_context(product, mode: product.persisted? ? :edit : :new)

      render json: entry_context.to_client_payload
    end

    private

    def find_product_for_context
      product_id = params[:product_id].presence || params.dig(:product, :id)
      return Product.find(product_id) if product_id.present?

      Product.new(
        active: true,
        publication_status: "active",
        catalog_item_type: "book",
        product_type: "physical",
        variation_type: "conditional"
      )
    end
  end
end
