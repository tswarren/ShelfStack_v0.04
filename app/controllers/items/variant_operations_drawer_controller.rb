# frozen_string_literal: true

module Items
  class VariantOperationsDrawerController < BaseController
    before_action -> { authorize!("items.catalog_items.view") }
    before_action :set_variant_and_item

    def show
      @drawer = VariantOperationsDrawerPresenter.for(
        item: @item,
        store: current_store,
        user: current_user,
        variant: @variant
      )

      render partial: "items/items/variant_operations_drawer_body",
             locals: { drawer: @drawer },
             layout: false
    end

    private

    def set_variant_and_item
      @variant = ProductVariant.includes(product: :catalog_item).find(params.require(:product_variant_id))
      @item = ItemPresenter.from_product_variant(@variant)
    end
  end
end
