# frozen_string_literal: true

require "csv"
require "set"

module Seeds
  module CsvSeedValidator
    DATA_DIR = Rails.root.join("db/seeds/data").freeze
    PRICING_MODELS = PricingModels::PRICING_MODELS.freeze

    Result = Data.define(:errors, :warnings) do
      def ok?
        errors.empty?
      end
    end

    module_function

    def call(data_dir: DATA_DIR)
      errors = []
      warnings = []

      tax_path = data_dir.join("tax_categories.csv")
      dept_path = data_dir.join("departments.csv")
      sub_path = data_dir.join("sub_departments.csv")
      rates_path = data_dir.join("store_tax_rates.csv")
      mappings_path = data_dir.join("store_tax_mappings.csv")
      dl_path = data_dir.join("display_locations.csv")
      sc_path = data_dir.join("store_categories.csv")
      bisac_path = data_dir.join("bisac.csv")
      genre_paths = {
        "music_genres" => data_dir.join("music_genres.csv"),
        "video_genres" => data_dir.join("video_genres.csv"),
        "video_game_genres" => data_dir.join("video_game_genres.csv"),
        "sideline_genres" => data_dir.join("sideline_genres.csv")
      }

      depts = read_csv(dept_path, errors)
      tax = read_csv(tax_path, errors)
      sub = read_csv(sub_path, errors)
      rates = read_csv(rates_path, errors)
      mappings = read_csv(mappings_path, errors)
      dl = read_csv(dl_path, errors)
      sc = read_csv(sc_path, errors)
      bisac = read_csv(bisac_path, errors)

      return Result.new(errors: errors, warnings: warnings) if errors.any? { |e| e.include?("parse error") }

      dept_nums = depts.map { |r| field(r, "department_number") }.compact.to_set
      tax_names = tax.map { |r| field(r, "name") }.compact.to_set

      validate_sub_departments!(sub, dept_nums, tax_names, errors)
      validate_store_tax_rates!(rates, errors)
      validate_store_tax_mappings!(mappings, tax_names, rates, errors)
      validate_display_locations!(dl, errors)
      validate_store_categories!(sc, sub, dl, dept_nums, errors)
      validate_bisac!(bisac, errors)
      genre_paths.each do |label, path|
        validate_genre_category_tree!(label, read_csv(path, errors), errors, warnings)
      end

      Result.new(errors: errors, warnings: warnings)
    end

    def read_csv(path, errors)
      rows = []
      CSV.foreach(path, headers: true) { |row| rows << row }
      rows
    rescue Errno::ENOENT
      errors << "#{path.basename}: file not found"
      []
    rescue CSV::MalformedCSVError => e
      errors << "#{path.basename}: parse error - #{e.message}"
      []
    end

    def field(row, name)
      row[name]&.strip.presence
    end

    def validate_sub_departments!(rows, dept_nums, tax_names, errors)
      keys = []
      rows.each do |row|
        k = field(row, "sub_department_key")
        keys << k
        dn = field(row, "department_number")
        errors << "sub_departments: unknown department #{dn} for key #{k}" if dn && !dept_nums.include?(dn)
        tn = field(row, "tax_category_name")
        errors << "sub_departments: unknown tax_category_name #{tn.inspect} for key #{k}" if tn && !tax_names.include?(tn)
        pm = field(row, "default_pricing_model")
        errors << "sub_departments: invalid pricing_model #{pm.inspect} for key #{k}" if pm && !PRICING_MODELS.include?(pm)
        sn = field(row, "short_name")
        errors << "sub_departments: short_name too long for key #{k}" if sn && sn.length > 20
      end
      keys.compact.group_by(&:itself).select { |_k, v| v.size > 1 }.each do |k, v|
        errors << "sub_departments: DUPLICATE key #{k} (#{v.size}x)"
      end
    end

    def validate_store_tax_rates!(rows, errors)
      rows.each do |row|
        bps = field(row, "tax_rate_bps")
        errors << "store_tax_rates: non-integer tax_rate_bps #{bps}" if bps && bps !~ /\A\d+\z/
      end
    end

    def validate_store_tax_mappings!(rows, tax_names, rates_rows, errors)
      rate_by_store = Hash.new { |h, k| h[k] = Set.new }
      rates_rows.each { |r| rate_by_store[field(r, "store_number")] << field(r, "rate_name") }

      rows.each do |row|
        tcn = field(row, "tax_category_name")
        sn = field(row, "store_number")
        srn = field(row, "store_tax_rate_name")
        errors << "store_tax_mappings: tax_category #{tcn.inspect} not found by name" if tcn && !tax_names.include?(tcn)
        errors << "store_tax_mappings: store #{sn} missing rate #{srn.inspect}" if sn && srn && !rate_by_store[sn].include?(srn)
      end
    end

    def validate_display_locations!(rows, errors)
      dl_short = rows.map { |r| field(r, "short_name") }.compact.to_set
      rows.each do |row|
        sn = field(row, "short_name")
        p = field(row, "parent_short_name")
        errors << "display_locations: parent #{p.inspect} not found for #{sn}" if p && !dl_short.include?(p)
      end
      dl_short_list = rows.map { |r| field(r, "short_name") }.compact
      dl_short_list.group_by(&:itself).select { |_k, v| v.size > 1 }.each_key do |k|
        errors << "display_locations: DUPLICATE short_name #{k}"
      end
    end

    def validate_store_categories!(rows, sub_rows, dl_rows, dept_nums, errors)
      sc_keys = rows.map { |r| field(r, "node_key")&.downcase }.compact
      sc_key_set = sc_keys.to_set
      sc_keys.group_by(&:itself).select { |_k, v| v.size > 1 }.each do |k, v|
        errors << "store_categories: DUPLICATE node_key #{k} (#{v.size}x)"
      end

      sub_keys = sub_rows.map { |r| field(r, "sub_department_key") }.compact.to_set
      dl_short = dl_rows.map { |r| field(r, "short_name") }.compact.to_set

      rows.each do |row|
        nk = field(row, "node_key")
        pk = field(row, "parent_node_key")
        errors << "store_categories: parent #{pk.inspect} not found for #{nk}" if pk && !sc_key_set.include?(pk.downcase)
        sdk = field(row, "default_sub_department_key")
        errors << "store_categories: unknown subdept #{sdk.inspect} on #{nk}" if sdk && !sub_keys.include?(sdk)
        dls = field(row, "default_display_location_short_name")
        errors << "store_categories: unknown display #{dls.inspect} on #{nk}" if dls && !dl_short.include?(dls)
        dn = field(row, "department_number")
        errors << "store_categories: unknown department_number #{dn} on #{nk}" if dn && !dept_nums.include?(dn)
        errors << "store_categories: node_key >30 chars: #{nk}" if nk && nk.length > 30
      end
    end

    def validate_bisac!(rows, errors)
      codes = rows.map { |r| field(r, "code") }
      errors << "bisac: #{codes.size - codes.uniq.size} duplicate codes" if codes.size != codes.uniq.size
      errors << "bisac: blank code rows" if codes.any?(&:blank?)
      rows.each { |r| errors << "bisac: blank heading for #{field(r, 'code')}" if field(r, "heading").blank? }
    end

    def validate_genre_category_tree!(label, rows, errors, warnings)
      return if rows.empty?

      keys = rows.map { |r| field(r, "node_key")&.downcase }.compact
      key_set = keys.to_set

      keys.group_by(&:itself).select { |_k, v| v.size > 1 }.each do |k, v|
        errors << "#{label}: DUPLICATE node_key #{k} (#{v.size}x)"
      end

      rows.each do |row|
        nk = field(row, "node_key")
        pk = field(row, "parent_node_key")
        errors << "#{label}: blank node_key" if nk.blank?
        errors << "#{label}: blank name for #{nk.inspect}" if nk.present? && field(row, "name").blank?
        errors << "#{label}: parent #{pk.inspect} not found for #{nk}" if pk && !key_set.include?(pk.downcase)
        errors << "#{label}: node_key >128 chars: #{nk}" if nk && nk.length > 128
        if nk && nk.length > CategoryNode::STANDARD_NODE_KEY_MAX_LENGTH && nk.length <= CategoryNode::GENRE_NODE_KEY_MAX_LENGTH
          # Expected for genre scheme CSV keys — validated at import via scheme-aware CategoryNode limit
        elsif nk && nk.length > CategoryNode::STANDARD_NODE_KEY_MAX_LENGTH
          errors << "#{label}: node_key >#{CategoryNode::STANDARD_NODE_KEY_MAX_LENGTH} chars: #{nk}"
        end
      end
    end
  end
end
