# frozen_string_literal: true

class TreeOrdering
  Row = Data.define(:record, :depth)

  DEFAULT_SORT = lambda { |left, right|
    left_sort = sort_order_for(left)
    right_sort = sort_order_for(right)
    left_label = sort_label_for(left)
    right_label = sort_label_for(right)

    [ left_sort, left_label ] <=> [ right_sort, right_label ]
  }.freeze

  def self.rows(records, parent_id: :parent_id, id: :id, sort: DEFAULT_SORT)
    new(records, parent_id: parent_id, id: id, sort: sort).rows
  end

  def self.sort_order_for(record)
    record.respond_to?(:sort_order) ? record.sort_order : 0
  end

  def self.sort_label_for(record)
    if record.respond_to?(:short_name) && record.short_name.present?
      record.short_name.to_s
    elsif record.respond_to?(:node_key) && record.node_key.present?
      record.node_key.to_s
    elsif record.respond_to?(:name)
      record.name.to_s
    else
      record.to_s
    end
  end

  def initialize(records, parent_id: :parent_id, id: :id, sort: DEFAULT_SORT)
    @records = Array(records)
    @parent_id = parent_id
    @id = id
    @sort = sort
  end

  def rows
    by_id = @records.index_by { |record| record.public_send(@id) }
    children_by_parent = group_children_by_parent

    ordered = []
    visited = {}

    top_level_parents(children_by_parent).each do |parent|
      append_subtree(ordered, visited, children_by_parent, parent, depth: 0)
    end

    orphan_roots(by_id, visited).each do |orphan|
      append_subtree(ordered, visited, children_by_parent, orphan, depth: 0)
    end

    ordered
  end

  private

  def group_children_by_parent
    children_by_parent = Hash.new { |hash, key| hash[key] = [] }

    @records.each do |record|
      parent_key = record.public_send(@parent_id)
      children_by_parent[parent_key] << record
    end

    children_by_parent
  end

  def top_level_parents(children_by_parent)
    children_by_parent[nil].sort(&@sort)
  end

  def orphan_roots(by_id, visited)
    @records
      .reject { |record| visited.key?(record.public_send(@id)) }
      .select { |record| orphan_root?(record, by_id) }
      .sort(&@sort)
  end

  def orphan_root?(record, by_id)
    parent_key = record.public_send(@parent_id)
    parent_key.present? && !by_id.key?(parent_key)
  end

  def append_subtree(ordered, visited, children_by_parent, record, depth:)
    record_id = record.public_send(@id)
    return if visited[record_id]

    visited[record_id] = true
    ordered << Row.new(record, depth)

    children_by_parent[record_id].sort(&@sort).each do |child|
      append_subtree(ordered, visited, children_by_parent, child, depth: depth + 1)
    end
  end
end
