# frozen_string_literal: true

# v0.04-6 verification — see Shelfstack::V0046Verify in lib/shelfstack/v0046_verify.rb

namespace :shelfstack do
  desc "Verify v0.04-6 demand foundation (STRICT=1 to fail on warnings)"
  task v0046_verify_demand_foundation: :environment do
    Rake::Task["shelfstack:v0046:verify_demand_foundation"].invoke
  end

  namespace :v0046 do
    desc "Verify v0.04-6 demand foundation"
    task verify_demand_foundation: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V0046Verify.report(strict: strict)

      puts "v0.04-6 demand foundation verification: #{result[:status]}"
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
