# frozen_string_literal: true

namespace :shelfstack do
  desc "Verify v0.04-16.1 unified product management / form stability (optional V004161_SLICE)"
  task "v004161:verify_unified_product_management": :environment do
    Shelfstack::V004161Verify.run!
  end
end
