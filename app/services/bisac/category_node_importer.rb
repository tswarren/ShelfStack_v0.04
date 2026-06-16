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
      scheme = ensure_scheme!
      created = 0
      updated = 0

      CategoryScheme.transaction do
        rows.sort_by(&:code).each do |row|
          node = scheme.category_nodes.find_or_initialize_by(node_key: row.code.downcase)
          was_new = node.new_record?
          node.assign_attributes(
            name: row.heading,
            parent: nil,
            sort_order: Hierarchy.sort_order(row.code),
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

      Result.new(created: created, updated: updated, total: rows.size, scheme: scheme)
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
  end
end
