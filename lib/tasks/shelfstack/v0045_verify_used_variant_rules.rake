# frozen_string_literal: true

# v0.04-5 verification — see Shelfstack::V0045Verify in lib/shelfstack/v0045_verify.rb

namespace :shelfstack do
  desc "Verify v0.04-5 used variant rules (report-only unless STRICT=1)"
  task v0045_verify_used_variant_rules: :environment do
    Rake::Task["shelfstack:v0045:verify_used_variant_rules"].invoke
  end

  namespace :v0045 do
    desc "Verify v0.04-5 used variant rules (report-only unless STRICT=1)"
    task verify_used_variant_rules: :environment do
      strict = ENV["STRICT"] == "1"
      puts "=== v0.04-5 Used Variant Rules Verification ==="
      puts "mode: #{strict ? 'STRICT (merge gate)' : 'report-only'}"

      data = Shelfstack::V0045Verify.report

      puts "new condition (condition_key: new) present: #{data[:new_condition_present]}"
      puts "buyback default (used_good) valid: #{data[:buyback_default_valid]}"
      puts "buyback_eligible + new_condition conditions: #{data[:buyback_eligible_marked_new].join(', ').presence || 'none'}"
      puts "used-like variants with orderable: true: #{data[:used_like_orderable_variant_count]}"
      puts "used-like variants in buildable TBO queue: #{data[:used_like_in_buildable_tbo_count]}"
      puts "buyback-created variants with non-211 SKU: #{data[:buyback_non_211_sku_count]}"
      puts "buyback-created variants on new condition: #{data[:buyback_new_condition_count]}"
      puts "suffix SKU generation paths outside allowlist: #{data[:suffix_sku_generation_paths].count}"
      data[:suffix_sku_generation_paths].each { |path| puts "  #{path}" }

      failures = Shelfstack::V0045Verify.strict_failures(data)

      if failures.any?
        puts "FAIL: #{failures.join('; ')}"
        exit 1 if strict
        puts "REPORT-ONLY: re-run with STRICT=1 at merge gate"
      else
        puts strict ? "PASS: verification complete" : "REPORT-ONLY: no blocking issues detected (enable STRICT=1 at merge gate)"
      end
    end

    desc "Dev-only: set orderable=false on active used-like variants (optional cleanup)"
    task repair_orderable_flags: :environment do
      Rake::Task["shelfstack:v0045_repair_orderable_flags"].invoke
    end
  end

  desc "Dev-only: set orderable=false on active used-like variants (optional cleanup)"
  task v0045_repair_orderable_flags: :environment do
    count = ProductVariant.active_records
      .joins(:condition)
      .where(product_conditions: { new_condition: false }, orderable: true)
      .update_all(orderable: false, updated_at: Time.current)

    puts "Updated orderable=false on #{count} used-like variant(s)."
  end
end
