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
    return false if mapping.merchandise_class_id.present? && mapping.merchandise_class_id != merchandise_class&.id
    return false if mapping.condition_id.present? && mapping.condition_id != variant.condition_id
    return false if mapping.product_type.present? && mapping.product_type != variant.product.product_type
    return false if mapping.category_node_id.present? && mapping.category_node_id != primary_topic_node&.id

    true
  end

  def merchandise_class
    variant.category&.merchandise_class
  end

  def primary_topic_node
    variant.categorizations.primary_records.includes(:category_node).first&.category_node
  end
end
