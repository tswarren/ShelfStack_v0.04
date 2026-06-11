# frozen_string_literal: true

class VariantTopicCategorization
  def self.sync!(variant:, category_node_id:, source: "manual")
    new(variant: variant, category_node_id: category_node_id, source: source).sync!
  end

  def initialize(variant:, category_node_id:, source: "manual")
    @variant = variant
    @category_node_id = category_node_id.presence
    @source = source
  end

  def sync!
    return remove_primary_categorizations! if category_node_id.blank?

    category_node = CategoryNode.active_records.find(category_node_id)
    existing = variant.categorizations.joins(:category_node)
                      .where(category_nodes: { category_scheme_id: category_node.category_scheme_id })
                      .first

    if existing
      existing.update!(category_node: category_node, primary: true, source: source)
    else
      variant.categorizations.create!(category_node: category_node, primary: true, source: source)
    end
  end

  private

  attr_reader :variant, :category_node_id, :source

  def remove_primary_categorizations!
    variant.categorizations.primary_records.destroy_all
  end
end
