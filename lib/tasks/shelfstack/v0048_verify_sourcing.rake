# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-8 sourcing (alias)"
  task v0048_verify_sourcing: :environment do
    Rake::Task["shelfstack:v0048:verify_sourcing"].invoke
  end

  namespace :v0048 do
    desc "Verify v0.04-8 sourcing and vendor responses (STRICT=1 to fail)"
    task verify_sourcing: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V0048Verify.report(strict: strict)

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
