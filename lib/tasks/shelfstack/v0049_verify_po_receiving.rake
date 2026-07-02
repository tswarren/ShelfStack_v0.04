# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-9 PO and receiving quantity model (alias)"
  task v0049_verify_po_receiving: :environment do
    Rake::Task["shelfstack:v0049:verify_po_receiving"].invoke
  end

  namespace :v0049 do
    desc "Verify v0.04-9 PO and receiving quantity model (STRICT=1 to fail)"
    task verify_po_receiving: :environment do
      strict = ENV["STRICT"].to_s == "1"
      result = Shelfstack::V0049Verify.report(strict: strict)

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
