# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-16 product entry revamp (optional V00416_SLICE)"
  task "v00416:verify_product_entry_revamp": :environment do
    Shelfstack::V00416Verify.run!
  end
end
