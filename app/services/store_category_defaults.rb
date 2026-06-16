# frozen_string_literal: true

class StoreCategoryDefaults
  Result = Data.define(
    :default_sub_department,
    :default_display_location,
    :source
  )

  def self.for(store_category_node:)
    new(store_category_node: store_category_node).call
  end

  def initialize(store_category_node:)
    @store_category_node = store_category_node
  end

  def call
    return empty_result if store_category_node.blank?

    Result.new(
      default_sub_department: store_category_node.default_sub_department,
      default_display_location: store_category_node.default_display_location,
      source: "store_category"
    )
  end

  private

  attr_reader :store_category_node

  def empty_result
    Result.new(default_sub_department: nil, default_display_location: nil, source: "none")
  end
end
