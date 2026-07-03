# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-11 documentation and schema cleanup (alias)"
  task v00411_verify_documentation_schema_cleanup: :environment do
    Rake::Task["shelfstack:v00411:verify_documentation_schema_cleanup"].invoke
  end

  namespace :v00411 do
    desc "Verify v0.04-11 documentation and schema cleanup (STRICT=1 to fail)"
    task verify_documentation_schema_cleanup: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V00411Verify.report(strict: strict)

      puts result[:summary]
      result[:checks].each do |key, ok|
        puts "  #{ok ? '✓' : '✗'} #{key}"
      end

      %i[forbidden_doc_hits schema_reference_dropped_table_hits app_dropped_model_hits].each do |detail_key|
        values = result.dig(:details, detail_key)
        next if values.blank?

        puts "#{detail_key}:"
        values.each { |hit| puts "  - #{hit}" }
      end

      if result[:failures].any?
        puts "Failures: #{result[:failures].join(', ')}"
        abort if strict
      end
    end
  end
end
