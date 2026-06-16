# frozen_string_literal: true

require "csv"

module Seeds
  module TsvTreeImporter
    module_function

    def parse_tsv(path)
      rows = []
      headers = nil

      File.foreach(path) do |line|
        line = line.delete("\n").strip
        next if line.blank? || line.start_with?("#")

        fields = line.split("\t", -1).map(&:strip)
        if headers.nil?
          headers = fields
          next
        end

        row = headers.each_with_index.to_h { |header, index| [ header, fields[index].presence ] }
        rows << row
      end

      rows
    end

    def import_display_locations!(path:)
      rows = parse_tsv(path)
      nodes_by_short_name = {}

      DisplayLocation.transaction do
        rows.each do |row|
          short_name = row.fetch("short_name")
          location = DisplayLocation.find_or_initialize_by(short_name: short_name)
          location.assign_attributes(
            name: row.fetch("name"),
            sort_order: row.fetch("sort_order", 0).to_i,
            active: true
          )
          location.save!
          nodes_by_short_name[short_name] = location
        end

        rows.each do |row|
          parent_short_name = row["parent_short_name"]
          next if parent_short_name.blank?

          location = nodes_by_short_name.fetch(row.fetch("short_name"))
          parent = nodes_by_short_name.fetch(parent_short_name)
          location.update!(parent: parent) if location.parent_id != parent.id
        end
      end

      nodes_by_short_name
    end

    def activate_display_locations_for_all_stores!
      Store.find_each do |store|
        DisplayLocation.active_records.find_each do |location|
          StoreDisplayLocation.find_or_initialize_by(store: store, display_location: location).tap do |record|
            record.linear_feet = 0
            record.active = true
            record.save!
          end
        end
      end
    end

    def sub_department_index
      SubDepartment.all.index_by(&:sub_department_key)
    end

    def display_location_index
      DisplayLocation.all.index_by(&:short_name)
    end

    def import_store_category_nodes!(scheme:, path:, sub_department_index: sub_department_index(),
                                     display_location_index: display_location_index())
      rows = parse_tsv(path)
      nodes_by_key = {}

      CategoryScheme.transaction do
        rows.each do |row|
          node_key = row.fetch("node_key").downcase
          node = scheme.category_nodes.find_or_initialize_by(node_key: node_key)
          node.assign_attributes(
            name: row.fetch("name"),
            sort_order: row.fetch("sort_order", 0).to_i,
            active: true
          )
          node.save!
          nodes_by_key[node_key] = node
        end

        rows.each do |row|
          node_key = row.fetch("node_key").downcase
          parent_key = row["parent_node_key"]&.downcase
          next if parent_key.blank?

          node = nodes_by_key.fetch(node_key)
          parent = nodes_by_key.fetch(parent_key)
          node.update!(parent: parent) if node.parent_id != parent.id
        end

        rows.each do |row|
          node_key = row.fetch("node_key").downcase
          node = nodes_by_key.fetch(node_key)
          sub_department = sub_department_index[row["default_sub_department_key"]]
          display_location = display_location_index[row["default_display_location_short_name"]]

          attrs = {}
          attrs[:default_sub_department_id] = sub_department.id if sub_department.present?
          attrs[:default_display_location_id] = display_location.id if display_location.present?
          node.update!(attrs) if attrs.any?
        end
      end

      nodes_by_key
    end
  end
end
