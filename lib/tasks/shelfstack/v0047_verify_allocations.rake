# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-7 allocations (alias)"
  task v0047_verify_allocations: :environment do
    Rake::Task["shelfstack:v0047:verify_allocations"].invoke
  end

  namespace :v0047 do
    desc "Verify v0.04-7 allocations and reservations (STRICT=1 to fail)"
    task verify_allocations: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V0047Verify.report(strict: strict)

      puts result[:summary]
      result[:checks].each do |key, ok|
        puts "  #{ok ? '✓' : '✗'} #{key}"
      end

      if result[:failures].any?
        puts "Failures: #{result[:failures].join(', ')}"
        abort if strict
      end
    end

    desc "Expire due demand lines and allocations (USERNAME= for manual actor)"
    task expire_due_demand: :environment do
      actor = if ENV["USERNAME"].present?
        User.find_by!(username: ENV["USERNAME"])
      else
        User.find_by!(username: ShelfStack::SYSTEM_USERNAME)
      end
      result = DemandLines::ExpireDue.call!(actor: actor)
      puts "Expired #{result.expired_demand_count} demand lines and #{result.expired_allocation_count} allocations."
    end
  end
end
