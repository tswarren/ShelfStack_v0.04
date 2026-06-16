# frozen_string_literal: true

module TreeSelectHelper
  TREE_SELECT_INDENT = "\u2003".freeze

  def tree_select_options(records, label_method: :name)
    return [] if records.blank?

    TreeOrdering.rows(Array(records)).map do |row|
      label = row.record.public_send(label_method)
      [ "#{TREE_SELECT_INDENT * row.depth}#{label}", row.record.id ]
    end
  end
end
