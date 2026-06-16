# frozen_string_literal: true

require "csv"

module Bisac
  class CsvReader
    DEFAULT_PATH = Pathname(ENV.fetch("BISAC_CSV_PATH", Rails.root.join("db/seeds/data/bisac.csv"))).freeze

    Row = Data.define(:code, :heading)

    def self.call(path: DEFAULT_PATH)
      new(path: path).call
    end

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def call
      raise ArgumentError, "BISAC CSV not found at #{path}" unless File.exist?(path)

      rows = []
      CSV.foreach(path, headers: true) do |row|
        code = row["code"]&.strip
        heading = row["heading"]&.strip
        next if code.blank? || heading.blank?

        rows << Row.new(code: Hierarchy.normalize_code(code), heading: heading)
      end

      rows
    end

    private

    attr_reader :path
  end
end
