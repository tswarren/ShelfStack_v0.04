# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-10 legacy ordering retirement (alias)"
  task v00410_verify_legacy_ordering_retired: :environment do
    Rake::Task["shelfstack:v00410:verify_legacy_ordering_retired"].invoke
  end

  namespace :v00410 do
    desc "Verify v0.04-10 legacy ordering retirement (STRICT=1 to fail; V00410_PHASE=g1|g2)"
    task verify_legacy_ordering_retired: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V00410Verify.report(strict: strict)

      puts result[:summary]
      result[:checks].each do |key, ok|
        puts "  #{ok ? '✓' : '✗'} #{key}"
      end

      if result[:failures].any?
        puts "Failures: #{result[:failures].join(', ')}"
        abort if strict
      end
    end
  end
end
