# frozen_string_literal: true

namespace :shelfstack do
  namespace :bisac do
    desc "Flatten BISAC category nodes (clear parent_id on all BISAC scheme nodes)"
    task flatten: :environment do
      scheme = CategoryScheme.find_by(scheme_key: Bisac::CategoryNodeImporter::SCHEME_KEY)
      if scheme.blank?
        puts "No BISAC scheme found."
        next
      end

      count = scheme.category_nodes.where.not(parent_id: nil).update_all(parent_id: nil)
      puts "Flattened #{count} BISAC nodes."
    end
  end
end
