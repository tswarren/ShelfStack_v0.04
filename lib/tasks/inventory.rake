# frozen_string_literal: true

namespace :shelfstack do
  namespace :inventory do
    desc "Rebuild inventory balances from ledger entries (requires USERNAME= with inventory.admin.rebuild_balances)"
    task rebuild_balances: :environment do
      actor = Inventory::AdminTaskAuthorization.authorize!(username: ENV["USERNAME"])
      count = Inventory::RebuildBalances.call(actor: actor)
      puts "Rebuilt #{count} inventory balance(s)."
    rescue Inventory::AdminTaskAuthorization::AuthorizationError => e
      warn e.message
      exit 1
    end

    desc "Check inventory balance integrity against ledger sums"
    task check_integrity: :environment do
      actor = if ENV["USERNAME"].present?
        Inventory::AdminTaskAuthorization.authorize!(username: ENV["USERNAME"])
      else
        User.find_by(username: ShelfStack::SYSTEM_USERNAME)
      end
      result = Inventory::BalanceIntegrityCheck.call(actor: actor)
      if result.passed
        puts "Inventory integrity check passed."
      else
        puts "Inventory integrity check failed (#{result.mismatches.size} mismatch(es)):"
        result.mismatches.each do |m|
          puts "  store=#{m.store_id} variant=#{m.product_variant_id} cached=#{m.cached_on_hand} ledger=#{m.ledger_on_hand}"
        end
        exit 1
      end
    rescue Inventory::AdminTaskAuthorization::AuthorizationError => e
      warn e.message
      exit 1
    end
  end
end
