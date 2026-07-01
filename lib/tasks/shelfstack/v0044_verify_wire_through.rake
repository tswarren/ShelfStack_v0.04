# frozen_string_literal: true

# v0.04-4 verification — see Shelfstack::V0044Verify in lib/shelfstack/v0044_verify.rb

namespace :shelfstack do
  namespace :v0044 do
    desc "Verify v0.04-4 variant-grain wire-through (report-only unless STRICT=1)"
    task verify_wire_through: :environment do
      strict = ENV["STRICT"] == "1"
      puts "=== v0.04-4 Variant-Grain Wire-Through Verification ==="
      puts "mode: #{strict ? 'STRICT (merge gate)' : 'report-only'}"

      legacy = Shelfstack::V0044Verify.legacy_reference_files
      puts "legacy identifier references in app/: #{legacy.count}"
      legacy.each { |row| puts "  #{row}" }

      catalog_refs = Shelfstack::V0044Verify.catalog_item_reference_files
      puts "uncategorized CatalogItem references in app/: #{catalog_refs.count}"
      catalog_refs.each { |row| puts "  #{row}" }

      url_refs = Shelfstack::V0044Verify.catalog_item_id_url_files
      puts "items_item_path(catalog_item_id:) outside allowlist: #{url_refs.count}"
      url_refs.each { |row| puts "  #{row}" }

      buyback_writes = Shelfstack::V0044Verify.buyback_created_catalog_item_writes
      puts "buyback services writing created_catalog_item: #{buyback_writes.count}"
      buyback_writes.each { |row| puts "  #{row}" }

      audit_dated = Shelfstack::V0044Verify.audit_table_dated?
      puts "spec audit table dated: #{audit_dated}"

      failures = []
      failures << "legacy identifier references remain" if legacy.any?
      failures << "uncategorized CatalogItem references" if catalog_refs.any?
      failures << "catalog_item_id item URLs outside allowlist" if url_refs.any?
      failures << "buyback intake sets created_catalog_item_id" if buyback_writes.any?
      failures << "spec audit table not dated" if strict && !audit_dated

      if failures.any?
        puts "FAIL: #{failures.join('; ')}"
        exit 1 if strict
        puts "REPORT-ONLY: re-run with STRICT=1 at merge gate"
      else
        puts strict ? "PASS: verification complete" : "REPORT-ONLY: no blocking issues detected (enable STRICT=1 at merge gate)"
      end
    end
  end
end
