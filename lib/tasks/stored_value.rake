# frozen_string_literal: true

namespace :shelfstack do
  namespace :stored_value do
    desc "Rebuild stored value account balances from ledger entries (requires USERNAME= with stored_value.admin.rebuild_balances)"
    task rebuild_balances: :environment do
      actor = StoredValue::AdminTaskAuthorization.authorize!(username: ENV["USERNAME"])
      count = StoredValue::RebuildBalances.call(actor: actor)
      puts "Rebuilt #{count} stored value account balance(s)."
    rescue StoredValue::AdminTaskAuthorization::AuthorizationError => e
      warn e.message
      exit 1
    end

    desc "Check stored value balance integrity against ledger sums"
    task integrity_check: :environment do
      actor = if ENV["USERNAME"].present?
        StoredValue::AdminTaskAuthorization.authorize!(username: ENV["USERNAME"])
      else
        User.find_by(username: ShelfStack::SYSTEM_USERNAME)
      end
      result = StoredValue::BalanceIntegrityCheck.call(actor: actor)
      if result.passed
        puts "Stored value integrity check passed."
      else
        puts "Stored value integrity check failed (#{result.mismatches.size} mismatch(es)):"
        result.mismatches.each do |m|
          puts "  account=#{m.stored_value_account_id} cached=#{m.cached_balance_cents} ledger=#{m.ledger_balance_cents}"
        end
        exit 1
      end
    rescue StoredValue::AdminTaskAuthorization::AuthorizationError => e
      warn e.message
      exit 1
    end
  end
end
