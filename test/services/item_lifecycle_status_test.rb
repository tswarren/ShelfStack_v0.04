# frozen_string_literal: true

require "test_helper"

class ItemLifecycleStatusTest < ActiveSupport::TestCase
  include Phase3TestHelper

  test "needs product when catalog shell has no product" do
    item = create_catalog_item!
    presenter = Items::ItemPresenter.from_catalog_item(item)

    assert_includes ItemLifecycleStatus.basic(presenter), "needs_product"
  end

  test "product created when product exists without variants" do
    product = create_product!
    presenter = Items::ItemPresenter.from_product(product)

    assert_includes ItemLifecycleStatus.basic(presenter), "product_created"
  end

  test "sellable when active variant exists" do
    variant = create_product_variant!
    presenter = Items::ItemPresenter.from_product(variant.product)

    assert_includes ItemLifecycleStatus.basic(presenter), "sellable"
  end

  test "full status includes inactive setup reference" do
    variant = create_product_variant!
    variant.condition.update!(active: false)
    presenter = Items::ItemPresenter.from_product(variant.product.reload)

    assert_includes ItemLifecycleStatus.full(presenter), "inactive_setup_reference"
  end
end
