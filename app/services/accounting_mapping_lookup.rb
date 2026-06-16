# frozen_string_literal: true

class AccountingMappingLookup
  def self.match_for(variant:)
    new(variant: variant).match
  end

  def initialize(variant:)
    @variant = variant
  end

  def match
    candidates = AccountingMapping.active_records.to_a
    candidates.select! { |mapping| matches?(mapping) }
    return nil if candidates.empty?

    candidates.max_by { |mapping| [mapping.specificity_score, -mapping.sort_order, -mapping.id] }
  end

  private

  attr_reader :variant

  def matches?(mapping)
    return false if mapping.sub_department_id.present? && mapping.sub_department_id != sub_department&.id
    return false if mapping.condition_id.present? && mapping.condition_id != variant.condition_id
    return false if mapping.product_type.present? && mapping.product_type != variant.product.product_type
    return false if mapping.category_node_id.present? && mapping.category_node_id != primary_topic_node&.id

    true
  end

  def sub_department
    variant.sub_department
  end

  def primary_topic_node
    variant.product&.catalog_item&.store_category
  end
end
