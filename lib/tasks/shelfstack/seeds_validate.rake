# frozen_string_literal: true

namespace :shelfstack do
  namespace :seeds do
    desc "Validate classification seed CSV files under db/seeds/data"
    task validate: :environment do
      require Rails.root.join("db/seeds/concerns/csv_seed_validator")

      result = Seeds::CsvSeedValidator.call
      result.warnings.each { |w| puts "WARN: #{w}" }

      if result.ok?
        puts "Seed CSV validation passed."
      else
        result.errors.each { |e| puts "ERROR: #{e}" }
        abort "Seed CSV validation failed (#{result.errors.size} errors)."
      end
    end
  end
end
