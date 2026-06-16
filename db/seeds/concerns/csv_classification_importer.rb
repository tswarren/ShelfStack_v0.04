# frozen_string_literal: true

require "csv"

module Seeds
  module CsvClassificationImporter
    DATA_DIR = Rails.root.join("db/seeds/data").freeze

    TAX_CATEGORIES_PATH = DATA_DIR.join("tax_categories.csv").freeze
    DEPARTMENTS_PATH = DATA_DIR.join("departments.csv").freeze
    SUB_DEPARTMENTS_PATH = DATA_DIR.join("sub_departments.csv").freeze
    STORE_TAX_RATES_PATH = DATA_DIR.join("store_tax_rates.csv").freeze
    STORE_TAX_MAPPINGS_PATH = DATA_DIR.join("store_tax_mappings.csv").freeze
    DISPLAY_LOCATIONS_PATH = DATA_DIR.join("display_locations.csv").freeze
    STORE_CATEGORIES_PATH = DATA_DIR.join("store_categories.csv").freeze

    module_function

    def read_csv(path)
      rows = []
      CSV.foreach(path, headers: true) do |row|
        next if row.fields.compact.empty?
        next if row.fields.first.to_s.strip.start_with?("#")

        rows << row
      end
      rows
    end

    def parse_boolean(value)
      return false if value.blank?

      value.to_s.strip.upcase.in?(%w[TRUE T YES Y 1])
    end

    def import_tax_categories!(path: TAX_CATEGORIES_PATH)
      read_csv(path).each do |row|
        TaxCategory.find_or_initialize_by(name: row.fetch("name").strip).tap do |tax_category|
          tax_category.short_name = row.fetch("short_name").strip
          tax_category.sort_order = row.fetch("sort_order").to_i
          tax_category.active = true
          tax_category.save!
        end
      end
    end

    def import_departments!(path: DEPARTMENTS_PATH)
      read_csv(path).each do |row|
        Department.find_or_initialize_by(department_number: row.fetch("department_number").strip).tap do |department|
          department.name = row.fetch("name").strip
          department.short_name = row.fetch("short_name").strip
          department.gl_account_code = row["gl_account_code"]&.strip.presence
          department.active = true
          department.save!
        end
      end
    end

    def import_sub_departments!(path: SUB_DEPARTMENTS_PATH)
      tax_categories_by_name = TaxCategory.all.index_by(&:name)
      departments_by_number = Department.all.index_by(&:department_number)

      read_csv(path).each do |row|
        key = row.fetch("sub_department_key").strip.downcase
        department = departments_by_number.fetch(row.fetch("department_number").strip)
        tax_category = tax_categories_by_name.fetch(row.fetch("tax_category_name").strip)

        SubDepartment.find_or_initialize_by(sub_department_key: key).tap do |sub_department|
          sub_department.department = department
          sub_department.name = row.fetch("name").strip
          sub_department.short_name = row.fetch("short_name").strip
          sub_department.default_pricing_model = row["default_pricing_model"]&.strip.presence
          sub_department.default_tax_category = tax_category
          sub_department.vendor_returnable_default = parse_boolean(row["vendor_returnable_default"])
          sub_department.buyback_allowed = parse_boolean(row["buyback_allowed"])
          sub_department.active = true
          sub_department.save!
        end
      end
    end

    def import_store_tax_rates!(path: STORE_TAX_RATES_PATH)
      read_csv(path).each do |row|
        store = Store.find_by!(store_number: row.fetch("store_number").strip)
        rate_name = row.fetch("rate_name").strip
        short_name = row.fetch("short_name").strip
        tax_identifier = row.fetch("tax_identifier").strip

        rate = store.store_tax_rates.find_by(name: rate_name)
        rate ||= store.store_tax_rates.find_by(short_name: short_name)
        rate ||= store.store_tax_rates.find_by(tax_identifier: tax_identifier)
        rate ||= store.store_tax_rates.build(name: rate_name)

        rate.assign_attributes(
          name: rate_name,
          short_name: short_name,
          tax_identifier: tax_identifier,
          tax_rate_bps: row.fetch("tax_rate_bps").to_i,
          active: true
        )
        rate.save!
      end
    end

    def import_store_tax_category_rates!(path: STORE_TAX_MAPPINGS_PATH)
      tax_categories_by_name = TaxCategory.all.index_by(&:name)

      read_csv(path).each do |row|
        store = Store.find_by!(store_number: row.fetch("store_number").strip)
        tax_category = tax_categories_by_name.fetch(row.fetch("tax_category_name").strip)
        store_tax_rate = store.store_tax_rates.find_by!(name: row.fetch("store_tax_rate_name").strip)
        effective_on = Date.parse(row.fetch("effective_on").strip)

        mapping = StoreTaxCategoryRate.find_by(store: store, tax_category: tax_category, effective_on: effective_on)
        mapping ||= StoreTaxCategoryRate.active_records.find_by(store: store, tax_category: tax_category)
        mapping ||= StoreTaxCategoryRate.new(store: store, tax_category: tax_category)

        mapping.assign_attributes(
          effective_on: effective_on,
          store_tax_rate: store_tax_rate,
          ends_on: row["ends_on"].present? ? Date.parse(row["ends_on"].strip) : nil,
          active: true
        )
        mapping.save!
      end
    end

    def import_display_locations!(path: DISPLAY_LOCATIONS_PATH)
      rows = read_csv(path)
      nodes_by_short_name = {}

      DisplayLocation.transaction do
        rows.each do |row|
          short_name = row.fetch("short_name").strip
          location = DisplayLocation.find_or_initialize_by(short_name: short_name)
          location.assign_attributes(
            name: row.fetch("name").strip,
            sort_order: row.fetch("sort_order").to_i,
            active: true
          )
          location.save!
          nodes_by_short_name[short_name] = location
        end

        rows.each do |row|
          parent_short_name = row["parent_short_name"]&.strip
          next if parent_short_name.blank?

          location = nodes_by_short_name.fetch(row.fetch("short_name").strip)
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

    def import_store_category_nodes!(scheme:, path: STORE_CATEGORIES_PATH,
                                     sub_department_index: sub_department_index(),
                                     display_location_index: display_location_index())
      rows = read_csv(path)
      nodes_by_key = {}
      csv_node_keys = rows.map { |row| row.fetch("node_key").strip.downcase }.to_set

      CategoryScheme.transaction do
        scheme.category_nodes.where.not(node_key: csv_node_keys).find_each do |legacy_node|
          legacy_node.update_columns(
            active: false,
            name: "[legacy] #{legacy_node.node_key}",
            parent_id: nil
          )
        end

        rows.each do |row|
          node_key = row.fetch("node_key").strip.downcase
          node = scheme.category_nodes.find_or_initialize_by(node_key: node_key)
          node.assign_attributes(
            name: row.fetch("name").strip,
            sort_order: row.fetch("sort_order").to_i,
            active: true
          )
          node.save!(validate: false)
          nodes_by_key[node_key] = node
        end

        rows.each do |row|
          node_key = row.fetch("node_key").strip.downcase
          parent_key = row["parent_node_key"]&.strip&.downcase
          next if parent_key.blank?

          node = nodes_by_key.fetch(node_key)
          parent = nodes_by_key.fetch(parent_key)
          if node.parent_id != parent.id
            node.parent = parent
            node.save!(validate: false)
          end
        end

        rows.each do |row|
          node_key = row.fetch("node_key").strip.downcase
          node = nodes_by_key.fetch(node_key)
          sub_department = sub_department_index[row["default_sub_department_key"]&.strip&.downcase]
          display_location = display_location_index[row["default_display_location_short_name"]&.strip]

          attrs = {}
          attrs[:default_sub_department_id] = sub_department.id if sub_department.present?
          attrs[:default_display_location_id] = display_location.id if display_location.present?
          if attrs.any?
            node.assign_attributes(attrs)
            node.save!(validate: false)
          end
        end

        nodes_by_key.each_value(&:save!)
      end

      nodes_by_key
    end
  end
end
