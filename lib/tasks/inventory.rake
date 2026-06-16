# frozen_string_literal: true

namespace :shelfstack do
  namespace :inventory do
    desc "Rebuild inventory balances from ledger entries"
    task rebuild_balances: :environment do
      actor = User.find_by(username: ShelfStack::SYSTEM_USERNAME)
      count = Inventory::RebuildBalances.call(actor: actor)
      puts "Rebuilt #{count} inventory balance(s)."
    end

    desc "Check inventory balance integrity against ledger sums"
    task check_integrity: :environment do
      result = Inventory::BalanceIntegrityCheck.call
      if result.passed
        puts "Inventory integrity check passed."
      else
        puts "Inventory integrity check failed (#{result.mismatches.size} mismatch(es)):"
        result.mismatches.each do |m|
          puts "  store=#{m.store_id} variant=#{m.product_variant_id} cached=#{m.cached_on_hand} ledger=#{m.ledger_on_hand}"
        end
        exit 1
      end
    end
  end
end
