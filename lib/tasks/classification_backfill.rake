# frozen_string_literal: true

namespace :shelfstack do
  namespace :classification do
    desc "Backfill store categories, product defaults, and subdepartments from legacy data"
    task backfill: :environment do
      stats = ClassificationBackfill.call
      stats.each { |label, count| puts "#{label}: #{count}" }
    end
  end
end
