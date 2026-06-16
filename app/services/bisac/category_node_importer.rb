# frozen_string_literal: true

module Bisac
  class CategoryNodeImporter
    Result = Data.define(:created, :updated, :total, :scheme)

    SCHEME_KEY = "bisac"
    SCHEME_NAME = "BISAC Subject Headings"

    def self.call(path: CsvReader::DEFAULT_PATH)
      new(path: path).call
    end

    def initialize(path: CsvReader::DEFAULT_PATH)
      @path = path
    end

    def call
      rows = CsvReader.call(path: path)
      nodes_by_code = build_node_definitions(rows)
      scheme = ensure_scheme!
      created = 0
      updated = 0

      CategoryScheme.transaction do
        nodes_by_code.values.sort_by { |node| [ node[:depth], node[:code] ] }.each do |definition|
          parent = definition[:parent_code].present? ? find_node!(scheme, definition[:parent_code]) : nil
          node = scheme.category_nodes.find_or_initialize_by(node_key: definition[:code].downcase)
          was_new = node.new_record?
          node.assign_attributes(
            name: definition[:heading],
            parent: parent,
            sort_order: Hierarchy.sort_order(definition[:code]),
            active: true
          )
          if was_new
            node.save!
            created += 1
          elsif node.changed?
            node.save!
            updated += 1
          end
        end
      end

      Result.new(created: created, updated: updated, total: nodes_by_code.size, scheme: scheme)
    end

    private

    attr_reader :path

    def ensure_scheme!
      CategoryScheme.find_or_initialize_by(scheme_key: SCHEME_KEY).tap do |scheme|
        scheme.name = SCHEME_NAME
        scheme.purpose = "bisac"
        scheme.active = true
        scheme.save!
      end
    end

    def build_node_definitions(rows)
      nodes_by_code = rows.index_by(&:code).transform_values do |row|
        {
          code: row.code,
          heading: row.heading,
          parent_code: Hierarchy.parent_code(row.code),
          depth: Hierarchy.depth(row.code)
        }
      end

      rows.each do |row|
        ensure_parent_nodes!(nodes_by_code, rows, Hierarchy.parent_code(row.code))
      end

      nodes_by_code
    end

    def ensure_parent_nodes!(nodes_by_code, rows, parent_code)
      return if parent_code.blank? || nodes_by_code.key?(parent_code)

      nodes_by_code[parent_code] = {
        code: parent_code,
        heading: synthetic_heading_for(parent_code, rows, nodes_by_code),
        parent_code: Hierarchy.parent_code(parent_code),
        depth: Hierarchy.depth(parent_code)
      }
      ensure_parent_nodes!(nodes_by_code, rows, Hierarchy.parent_code(parent_code))
    end

    def synthetic_heading_for(parent_code, rows, nodes_by_code)
      child = rows.find { |row| Hierarchy.parent_code(row.code) == parent_code }
      raise ArgumentError, "Unable to infer heading for synthetic BISAC node #{parent_code}" if child.blank?

      candidate = Hierarchy.synthetic_heading(parent_code, child_heading: child.heading)
      return candidate unless heading_taken?(nodes_by_code, parent_code, candidate)

      disambiguated = "#{candidate} [#{parent_code}]"
      return disambiguated unless heading_taken?(nodes_by_code, parent_code, disambiguated)

      raise ArgumentError, "Unable to infer unique heading for synthetic BISAC node #{parent_code}"
    end

    def heading_taken?(nodes_by_code, parent_code, heading)
      nodes_by_code.values.any? do |node|
        node[:parent_code] == parent_code && node[:heading] == heading
      end
    end

    def find_node!(scheme, code)
      scheme.category_nodes.find_by!(node_key: code.downcase)
    end
  end
end
